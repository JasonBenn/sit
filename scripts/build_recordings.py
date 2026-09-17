#!/usr/bin/env python3 -u
"""Build app/recordings.json and the per-recording transcripts the search greps.

Source of truth is the Meditations tree: <root>/<drive folder>/<title>.mp3 with a
Whisper <title>_transcription.json beside each recording. On nose that root is the
rclone mirror of Google Drive (/opt/sit-media/drive/Meditations), so the script runs
there and writes transcripts straight into MEDIA_DIR; on the Mac it is the Drive
folder behind ~/code/meditation-clipper/Meditations, which only a process with Full
Disk Access can read:

    tmux -L fda run-shell -b "sh -c 'cd ~/code/sit && \
        ANTHROPIC_API_KEY=... python3 scripts/build_recordings.py' > /tmp/build.log 2>&1"

Audio is never copied: the app serves /media/recordings/<id>.mp3 from the mirror,
resolved through the index's folder + title. Idempotent: durations and summaries
already in app/recordings.json are reused.
"""

import argparse
import concurrent.futures
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
import unicodedata
from pathlib import Path

MIRROR = Path("/opt/sit-media/drive/Meditations")
MAC_DRIVE = Path.home() / "code" / "meditation-clipper" / "Meditations"
REPO = Path(__file__).resolve().parent.parent
INDEX = REPO / "app" / "recordings.json"
MEDIA_DIR = Path(os.getenv("MEDIA_DIR", "/opt/sit-media"))
STAGING = Path(
    "/private/tmp/claude-501/-Users-jasonbenn-code-sit/"
    "20f9548e-4c56-444a-bef2-1ed30f23c184/scratchpad/media"
)
NOSE_MEDIA = "nose:/opt/sit-media/"

# drive folder -> (collection label, id prefix). Only these folders are read;
# "Jhourney Recordings" (13 GiB, duplicates of the retreat tracks) never is.
COLLECTIONS = {
    "Ridgzin - Recordings": ("Rigdzin recordings", "rec"),
    "Rigdzin Charity 2025-01-03": ("Rigdzin charity retreat", "charity"),
    "Rigdzin - Advanced": ("Rigdzin advanced course", "adv"),
    "Rigdzin - Intermeditate": ("Rigdzin intermediate course", "int"),
    "Rigdzin-Intro": ("Rigdzin intro retreat", "intro"),
    "Jhourney - in-person retreat 12 Nov": ("Jhourney retreat", "jhourney"),
    "Burbea - Jhanas": ("Burbea", "burbea"),
    "My clips": ("Jason's clips", "clips"),
}

SUMMARY_PROMPT = """Here is the transcript of a guided meditation recording titled "{title}".

<transcript>
{transcript}
</transcript>

Write exactly two sentences describing it for a meditation library index.
The first sentence says concretely what the practice does, step by step, in the
order it happens. The second sentence begins "Reach for it when" and names the
morning state it serves.

Match the voice of these examples:

"Three investigations of thought itself, not its content: where it happens, how it
comes and goes, and whether it has size, shape, or color. Reach for it when the mind
is busy and looping and watching thoughts go by is not working."

"Whole-body awareness through five escalating intentions: relax, release, allow,
watch, rest. Reach for it when you are trying too hard and cannot make yourself relax."

Plain prose, no markdown, no preamble. Output only the two sentences."""


# ---------------------------------------------------------------- parsing


def slugify(title):
    """'Emptiness of Thought - 20min(Stages23)' -> 'emptiness-of-thought-20min-stages23'."""
    # Drop the trailing [hash] / [youtube id] that some exports append.
    title = re.sub(r"\s*\[[0-9A-Za-z_-]{8,}\]\s*$", "", title)
    title = unicodedata.normalize("NFKD", title)
    title = "".join(c for c in title if not unicodedata.combining(c))
    title = re.sub(r"[^0-9A-Za-z]+", "-", title.lower())
    return title.strip("-")


def transcript_lines(data):
    """[(seconds, text)] from a Whisper JSON, built the way meditation-clipper's
    export_notebooklm.py builds its .txt files: one line per sentence timed by its
    first word when word timings exist, else one per segment, else the whole text."""
    words, text = data.get("words") or [], (data.get("text") or "").strip()
    if words and text:
        sentences = [m.group(0).strip() for m in re.finditer(r"[^.!?]*[.!?]|[^.!?]+$", text)]
        starts = []  # character offset at which each word begins, in the text
        pos = 0
        for w in words:
            starts.append((pos, w.get("start", 0)))
            pos += len(w.get("word", "")) + 1
        out, cursor = [], 0
        for sentence in sentences:
            if not sentence:
                continue
            at = text.find(sentence, cursor)
            if at == -1:
                continue
            stamp = next((t for off, t in starts if off >= at), 0)
            out.append((int(stamp), sentence))
            cursor = at + len(sentence)
        return out
    if data.get("segments"):
        return [(int(seg.get("start", 0)), seg["text"].strip())
                for seg in data["segments"] if seg.get("text", "").strip()]
    return [(0, text)] if text else []


def is_guided(folder, title, lines):
    """Per-collection filter: which of a folder's recordings are guided sits."""
    if folder in ("Rigdzin - Advanced", "Rigdzin - Intermeditate"):
        # NNNm = meditation; NNNq = Q&A, NNNt = talk.
        return bool(re.match(r"^\d{3}m", title))
    if folder == "Rigdzin-Intro":
        # 'Med:' = meditation; 'Q&A:' and 'Overview of' are not. The colon is
        # fullwidth (：) in the export, so match the prefix only.
        return title.startswith("Med")
    if folder in ("Ridgzin - Recordings", "Rigdzin Charity 2025-01-03", "My clips"):
        return True
    if folder == "Burbea - Jhanas":
        # Two real guided sits; '14 True to Your Deepest Desires' is a talk with a
        # four-minute guided tail, so the 'Talk and' variant is out.
        return "Guided Meditation)" in title and "Talk and" not in title
    if folder == "Jhourney - in-person retreat 12 Nov":
        # The retreat's numbered tracks are nearly all sits. Out: the EXTRA
        # tracks (third-party teachers and music), the journaling/expectation
        # exercises and the opening instructions talk, and any track whose
        # transcript degenerated into repeated fragments over silence.
        if "EXTRA" in title:
            return False
        if re.search(r"exercise|expectations|instructions", title, re.I):
            return False
        if lines:
            chars = sum(len(t) for _, t in lines)
            if chars / len(lines) < 20:  # Whisper looping on a silent track
                return False
        return True
    return False


def collect_recordings(root):
    recs = []
    stats = {}
    for folder, (collection, prefix) in COLLECTIONS.items():
        paths = sorted((root / folder).glob("*_transcription.json"))
        kept = []
        for path in paths:
            title = path.name[: -len("_transcription.json")]
            lines = transcript_lines(json.loads(path.read_text(encoding="utf-8")))
            if not is_guided(folder, title, lines):
                continue
            kept.append(
                {
                    "id": f"{prefix}-{slugify(title)}",
                    "title": title,
                    "folder": folder,
                    "collection": collection,
                    "_lines": lines,
                }
            )
        stats[folder] = (len(paths), len(kept))
        recs.extend(kept)
    return recs, stats


# ------------------------------------------------------------ manifests


def norm_name(name):
    """NFC-fold a filename: the manifests and the Drive tree disagree on how they
    compose accented characters (Jhānas), so compare on one normal form."""
    return unicodedata.normalize("NFC", name).lower()


def norm_folder(name):
    n = unicodedata.normalize("NFKD", name).lower()
    n = re.sub(r"[^0-9a-z]+", "", n)
    n = n.replace("ridgzin", "rigdzin")
    if n.startswith("rigdzin"):
        n = n[len("rigdzin") :]
    return n


def load_component_map():
    """(normalized folder, lowercased mp3 name) -> [slug]; a basename fallback; and
    slug -> the name Jason wrote for that component."""
    by_pair, by_base, names = {}, {}, {}
    for path in sorted((REPO / "scripts").glob("*_manifest.json")):
        for entry in json.loads(path.read_text()):
            names[entry["slug"]] = entry.get("name") or ""
            source = entry.get("source") or ""
            if not source.endswith(".mp3") or "/" not in source:
                continue
            folder, base = source.rsplit("/", 1)
            if os.path.isabs(source):
                continue  # already-cut clips, not corpus recordings
            by_pair.setdefault((norm_folder(folder), norm_name(base)), []).append(entry["slug"])
            by_base.setdefault(norm_name(base), []).append(entry["slug"])
    return by_pair, by_base, names


# ----------------------------------------------------------------- names


VARIANT_SUFFIX = re.compile(r"\s*\((?:full|short)\)$", re.I)
COURSE_CODE = re.compile(r"^\d{3}[a-z]\s+")
MED_PREFIX = re.compile(r"^Med[:：]\s*")
BRACKETED = re.compile(r"\s*\[[^\]]*\]")
PARENTHETICAL = re.compile(r"\s*\([^)]*\)")


def display_name(rec, names):
    """What the card shows. Most titles are course codes or export filenames
    ('102m dorje', 'Med： emptiness - body (Wed 5) [7c37…]'), so prefer the name
    Jason already wrote for the cut component — the full variant when there is
    one — and otherwise strip the codes, hashes and duration hints out."""
    for slug in sorted(rec["component_slugs"], key=lambda s: not s.endswith("-full")):
        name = VARIANT_SUFFIX.sub("", names.get(slug, "")).strip()
        if name:
            return name
    name = rec["title"].replace("⭐", " ").replace("️", "")
    name = name.replace("_modified", "").replace("_transcription", "")
    name = PARENTHETICAL.sub("", BRACKETED.sub("", name)).strip()
    name = MED_PREFIX.sub("", COURSE_CODE.sub("", name))
    name = " ".join(name.split()).strip(" -–—")
    return name[:1].upper() + name[1:]


# ------------------------------------------------------------------ audio


FFPROBE = shutil.which("ffprobe") or "/usr/local/bin/ffprobe"


def run(cmd, timeout):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def probe(mp3):
    """(duration_s, reason). duration 0 means the file is not playable."""
    if not mp3.exists():
        return 0, "no mp3"
    if mp3.stat().st_size < 1024:
        return 0, "empty file (cloud-only placeholder)"
    try:
        out = run(
            [FFPROBE, "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", str(mp3)],
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return 0, "ffprobe timed out"
    if out.returncode != 0 or not out.stdout.strip():
        return 0, f"ffprobe failed: {out.stderr.strip()[:80]}"
    return int(round(float(out.stdout.strip()))), ""


# -------------------------------------------------------------- summaries


def summarize(client, rec):
    body = "\n".join(t for _, t in rec["_lines"] if t)
    if len(body) > 12000:
        body = body[:12000]
    for attempt in range(6):
        try:
            return _one_summary(client, rec["title"], body)
        except Exception as exc:  # 429 / 529 / transient network
            if attempt == 5:
                raise
            time.sleep(min(60, 4 * 2**attempt) + random.uniform(0, 3))
            print(f"  retry {rec['id']} ({type(exc).__name__})")


def _one_summary(client, title, body):
    msg = client.messages.create(
        model="claude-sonnet-5",
        max_tokens=1000,
        messages=[
            {
                "role": "user",
                "content": SUMMARY_PROMPT.format(title=title, transcript=body),
            }
        ],
    )
    # by type, not position: a thinking block may come first
    text = next(b.text for b in msg.content if b.type == "text")
    return " ".join(text.split())


# ------------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--meditations", type=Path, default=MIRROR if MIRROR.is_dir() else MAC_DRIVE,
                    help="Meditations root: the nose mirror, or the Mac's Drive folder")
    ap.add_argument("--out", type=Path,
                    default=MEDIA_DIR / "transcripts" if MIRROR.is_dir() else STAGING / "transcripts",
                    help="where the per-recording transcripts go")
    ap.add_argument("--no-rsync", action="store_true", help="(Mac) don't ship transcripts to nose")
    ap.add_argument("--no-summaries", action="store_true")
    ap.add_argument("--reprobe", action="store_true", help="re-read every mp3's duration")
    ap.add_argument("--limit", type=int, help="only process the first N recordings")
    args = ap.parse_args()

    recs, stats = collect_recordings(args.meditations)
    if args.limit:
        recs = recs[: args.limit]

    dupes = {r["id"] for r in recs if sum(1 for x in recs if x["id"] == r["id"]) > 1}
    if dupes:
        sys.exit(f"duplicate ids: {sorted(dupes)}")

    by_pair, by_base, names = load_component_map()
    prior = {}
    if INDEX.exists() and not args.reprobe:
        prior = {
            r["id"]: r for r in json.loads(INDEX.read_text())
            if r.get("duration_s") is not None and "hosted" in r
        }

    print(f"parsed {len(recs)} guided recordings from {args.meditations}")
    for folder, (total, kept) in stats.items():
        print(f"  {folder:36s} {kept:3d} guided of {total:3d}")

    # ---- durations and transcripts
    args.out.mkdir(parents=True, exist_ok=True)
    not_hosted, reused = [], 0
    for i, rec in enumerate(recs, 1):
        if rec["id"] in prior:
            rec["duration_s"] = prior[rec["id"]]["duration_s"]
            rec["hosted"] = prior[rec["id"]]["hosted"]
            reused += 1
        else:
            duration, reason = probe(args.meditations / rec["folder"] / f"{rec['title']}.mp3")
            rec["duration_s"] = duration
            rec["hosted"] = duration > 0
            if not rec["hosted"]:
                not_hosted.append((rec["id"], rec["title"], reason))
                print(f"[{i}/{len(recs)}] SKIP {rec['id']}: {reason}")
            else:
                print(f"[{i}/{len(recs)}] {rec['id']} {duration}s")
        if rec["hosted"]:
            (args.out / f"{rec['id']}.txt").write_text(
                "\n".join(f"[{s // 60:02d}:{s % 60:02d}] {t}" for s, t in rec["_lines"] if t),
                encoding="utf-8",
            )

    # ---- component slugs
    for rec in recs:
        key = (norm_folder(rec["folder"]), norm_name(f"{rec['title']}.mp3"))
        slugs = by_pair.get(key) or by_base.get(key[1]) or []
        rec["component_slugs"] = sorted(set(slugs))
        rec["name"] = display_name(rec, names)

    # ---- summaries (cached in the committed index)
    cache = {}
    if INDEX.exists():
        cache = {r["id"]: r.get("summary", "") for r in json.loads(INDEX.read_text())}
    side = args.out.parent / "summaries.json"   # survives a killed run
    if side.exists():
        cache.update({k: v for k, v in json.loads(side.read_text()).items() if v})
    for rec in recs:
        rec["summary"] = cache.get(rec["id"], "")

    failed = []
    todo = [r for r in recs if r["hosted"] and not r["summary"]]
    if todo and not args.no_summaries:
        import anthropic

        client = anthropic.Anthropic(timeout=120.0, max_retries=5)
        print(f"summarizing {len(todo)}")
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            futures = {pool.submit(summarize, client, r): r for r in todo}
            for n, fut in enumerate(concurrent.futures.as_completed(futures), 1):
                rec = futures[fut]
                try:
                    rec["summary"] = fut.result()
                except Exception as exc:
                    failed.append((rec["id"], f"{type(exc).__name__}: {exc}"))
                    continue
                cache[rec["id"]] = rec["summary"]
                side.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
                print(f"  ({n}/{len(todo)}) {rec['id']}")
    elif todo:
        print(f"skipping {len(todo)} summaries (--no-summaries)")

    # ---- index
    index = [
        {
            "id": r["id"],
            "title": r["title"],
            "folder": r["folder"],
            "name": r["name"],
            "collection": r["collection"],
            "duration_s": r["duration_s"],
            "hosted": r["hosted"],
            "summary": r["summary"],
            "component_slugs": r["component_slugs"],
        }
        for r in sorted(recs, key=lambda r: r["id"])
    ]
    if args.limit:
        print(f"--limit {args.limit}: not overwriting {INDEX.name}")
    else:
        INDEX.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    # ---- ship (Mac only: on nose the transcripts were written in place)
    if not args.no_rsync and not MIRROR.is_dir():
        print("rsyncing transcripts to nose")
        subprocess.run(
            ["rsync", "-a", "--partial", f"{args.out}/", NOSE_MEDIA + "transcripts/"],
            check=True,
        )

    hosted = sum(r["hosted"] for r in recs)
    total_s = sum(r["duration_s"] for r in recs)
    print(f"\n{len(recs)} recordings, {hosted} hosted, {reused} durations reused from the index")
    print(f"total duration {total_s // 3600}h{total_s % 3600 // 60:02d}m")
    if failed:
        print(f"summaries failed ({len(failed)}):")
        for rid, err in failed:
            print(f"  {rid} — {err}")
    if not_hosted:
        print(f"not hosted ({len(not_hosted)}):")
        for rid, title, reason in not_hosted:
            print(f"  {rid} — {title} — {reason}")


if __name__ == "__main__":
    main()
