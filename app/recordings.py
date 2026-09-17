"""Guided-meditation search: the recordings index, their transcripts, and the
Sonnet call that picks the few that fit what the user brought this morning.

Separate from the practice library: these are whole source recordings, played
straight from the player, not the hand-cut components the runner plays. A
recording that also has a cut component says so, and the model can offer the
component with propose_program instead.
"""
import json
import os
import re
from datetime import datetime, timedelta, timezone as tz
from typing import Optional

import anthropic
from sqlmodel import select

from app.models import Listen, Sit

# Built by scripts/build_recordings.py and committed; the transcripts and audio
# it references live outside the repo, under MEDIA_DIR.
INDEX_PATH = os.path.join(os.path.dirname(__file__), "recordings.json")
MEDIA_DIR = os.getenv("MEDIA_DIR", "/opt/sit-media")

SELECTOR_MODEL = "claude-sonnet-5"
MAX_CHOICES = 4
RECENT_DAYS = 30
SNIPPET_WIDTH = 160

TIMESTAMP_RE = re.compile(r"^\[\d+:\d+(?::\d+)?\]\s*")


def _load_index() -> list[dict]:
    """Absent before the first build — the app still boots, search just finds
    nothing."""
    if not os.path.exists(INDEX_PATH):
        return []
    with open(INDEX_PATH) as f:
        return json.load(f)


def _load_transcripts(index: list[dict]) -> dict[str, list[str]]:
    """One list of spoken lines per recording, for the snippet grep. A recording
    whose transcript isn't on this box is searchable by its summary alone."""
    directory = os.path.join(MEDIA_DIR, "transcripts")
    transcripts = {}
    for recording in index:
        path = os.path.join(directory, f"{recording['id']}.txt")
        if not os.path.exists(path):
            continue
        with open(path) as f:
            lines = [TIMESTAMP_RE.sub("", line).strip() for line in f]
        transcripts[recording["id"]] = [line for line in lines if line]
    return transcripts


RECORDINGS = _load_index()
BY_ID = {r["id"]: r for r in RECORDINGS}
TRANSCRIPTS = _load_transcripts(RECORDINGS)


def audio_path(rec_id: str) -> str:
    """The original mp3 in the Drive mirror. Ids stay in URLs so the Drive names
    — spaces, fullwidth colons, emoji, hashes — never do."""
    r = BY_ID[rec_id]  # unknown id: let it crash
    return os.path.join(MEDIA_DIR, "drive", "Meditations", r["folder"], f"{r['title']}.mp3")


# Long enough to pass the four-letter filter, but present in every transcript,
# so they'd return snippets that say nothing about the match.
STOPWORDS = {
    "about", "been", "could", "feel", "feels", "feeling", "from", "have", "into",
    "just", "like", "more", "morning", "much", "really", "some", "something",
    "than", "that", "them", "then", "they", "this", "very", "want", "wants",
    "what", "when", "will", "with", "would",
}


def keywords(inquiry: str) -> list[str]:
    """The words of the inquiry worth grepping for, cut to a four-character
    prefix so "settling" also finds "settle" and "settled"."""
    words = re.findall(r"[a-z]+", inquiry.lower())
    return list(dict.fromkeys(w[:4] for w in words if len(w) >= 4 and w not in STOPWORDS))


def snippets(lines: list[str], keys: list[str], limit: int = 2) -> list[str]:
    """Up to `limit` transcript lines mentioning the inquiry — the evidence the
    selector gets beyond the summary."""
    found = []
    for line in lines:
        lowered = line.lower()
        if any(key in lowered for key in keys):
            found.append(line[:SNIPPET_WIDTH].strip())
            if len(found) == limit:
                break
    return found


def recent_from(listens: list[str], programs: list[dict], index: list[dict]) -> set[str]:
    """The pure half of recent_ids: recordings played directly, plus recordings
    whose cut component was played as part of a sit's program."""
    heard = set(listens)
    slugs = {
        component["slug"]
        for program in programs
        for component in program.get("components", [])
        if component.get("kind") == "guided"
    }
    for recording in index:
        if slugs.intersection(recording.get("component_slugs") or []):
            heard.add(recording["id"])
    return heard


def recent_ids(session, now: Optional[datetime] = None) -> set[str]:
    """Recordings heard in the last 30 days, which search skips so the mornings
    don't loop on one favourite."""
    now = now or datetime.now(tz.utc)
    cutoff = now - timedelta(days=RECENT_DAYS)
    listens = session.exec(
        select(Listen.recording_id).where(Listen.started_at >= cutoff)
    ).all()
    programs = session.exec(
        select(Sit.program_json).where(Sit.started_at >= cutoff)
    ).all()
    return recent_from(list(listens), [p for p in programs if p], RECORDINGS)


def _minutes(seconds: int) -> int:
    return round(seconds / 60)


SELECTOR_PROMPT = """The user is checking in before a morning meditation. Pick the guided \
meditations from their own library that would genuinely serve what they brought this morning.

What they're working with: {inquiry}

Candidates, as `id · title · collection · length · summary`, with any transcript lines that \
matched their words indented beneath:

{candidates}

Choose zero to {max_choices}. Fewer is better than padding, and returning none is a real \
answer — do that when nothing here actually fits. Spread the choices across different \
approaches and different collections rather than offering four takes on the same practice.

Respond with a JSON array and nothing else, one object per choice, in the order you'd offer \
them:
[{{"id": "<id>", "why": "one clause, addressed to the user, on why this one this morning"}}]"""


def _candidate_text(recording: dict, keys: list[str]) -> str:
    line = (f"{recording['id']} · {recording['title']} · {recording['collection']} · "
            f"{_minutes(recording['duration_s'])} min · {recording['summary']}")
    for snippet in snippets(TRANSCRIPTS.get(recording["id"], []), keys):
        line += f'\n    "{snippet}"'
    return line


def parse_choices(text: str, known_ids: set[str]) -> list[dict]:
    """The first `[`…`]` span, strictly parsed. A malformed answer means the tool
    found nothing rather than half a card — the model can still offer silence."""
    start, end = text.find("["), text.rfind("]")
    if start == -1 or end < start:
        return []
    try:
        data = json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    choices = []
    for item in data:
        if isinstance(item, dict) and item.get("id") in known_ids:
            choices.append({"id": item["id"], "why": str(item.get("why", "")).strip()})
    return choices[:MAX_CHOICES]


def _select(inquiry: str, candidates: list[dict], keys: list[str]) -> list[dict]:
    # Sonnet spends most of its budget thinking before the array: a tight cap
    # truncates the JSON, and a truncated answer parses to no choices at all.
    client = anthropic.Anthropic(timeout=30)
    response = client.messages.create(
        model=SELECTOR_MODEL,
        max_tokens=4000,
        messages=[{"role": "user", "content": SELECTOR_PROMPT.format(
            inquiry=inquiry,
            candidates="\n".join(_candidate_text(c, keys) for c in candidates),
            max_choices=MAX_CHOICES,
        )}],
    )
    text = "".join(block.text for block in response.content if block.type == "text")
    return parse_choices(text, {c["id"] for c in candidates})


def find(
    session, inquiry: str, max_minutes: Optional[int] = None,
    now: Optional[datetime] = None,
) -> list[dict]:
    """Zero to four hosted recordings that fit the inquiry, in the selector's
    order, skipping anything heard in the last month."""
    recent = recent_ids(session, now)
    candidates = [
        r for r in RECORDINGS
        if r.get("hosted") and r["id"] not in recent
        and (max_minutes is None or r["duration_s"] <= max_minutes * 60)
    ]
    if not candidates:
        return []
    by_id = {r["id"]: r for r in candidates}
    keys = keywords(inquiry)
    return [
        {
            "id": choice["id"],
            "name": by_id[choice["id"]]["name"],
            "title": by_id[choice["id"]]["title"],
            "collection": by_id[choice["id"]]["collection"],
            "duration_s": by_id[choice["id"]]["duration_s"],
            "summary": by_id[choice["id"]]["summary"],
            "why": choice["why"],
            "component_slugs": by_id[choice["id"]].get("component_slugs") or [],
        }
        for choice in _select(inquiry, candidates, keys)
    ]


NO_FIT = "No guided meditation fits; suggest an unguided sit."
RESULT_NOTE = ("[The card is already shown to the user — don't re-list it. Say one line; "
               "if one of the cut components fits this morning better than the whole "
               "recording, propose it with propose_program.]")


def tool_result_text(choices: list[dict]) -> str:
    """What the model reads back from the tool: one line per choice, plus the
    reminder that the user is already looking at the card."""
    if not choices:
        return NO_FIT
    lines = []
    for choice in choices:
        line = (f"{choice['name']} ({_minutes(choice['duration_s'])} min, "
                f"{choice['collection']}): {choice['why']}")
        if choice["component_slugs"]:
            line += " — also cut as [" + ", ".join(choice["component_slugs"]) + "]"
        lines.append(line)
    return "\n".join(lines) + "\n\n" + RESULT_NOTE


def replay_suffix(data: dict) -> str:
    """The tail of the options marker when the conversation is replayed: what was
    offered, and what the user actually played."""
    names = "; ".join(c["name"] for c in data["choices"])
    suffix = f" → {names}" if names else " → nothing fit"
    played = data.get("played")
    if played:
        name = next((c["name"] for c in data["choices"] if c["id"] == played), played)
        suffix += f" — played: {name}"
    return suffix
