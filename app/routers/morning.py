"""Morning sit dashboard: session-scoped check-in conversations with two tools —
ask the Rigdzin NotebookLM notebook, and write/update a wake-up log journal entry.

No auth: this router is only reachable over Tailscale (the public vhost 404s it).
"""
import json
import logging
import os
import re
import subprocess
from datetime import date, datetime, timedelta, timezone as tz
from typing import Optional
from uuid import UUID
from zoneinfo import ZoneInfo

import anthropic
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlmodel import Session, select

from app import journal, library, recordings
from app.db import engine, get_session
from app.models import Listen, MorningMessage, MorningSession, Sit, User

router = APIRouter(prefix="/api/morning", tags=["morning"])

MODEL = "claude-fable-5"
MORNING_USERNAME = os.getenv("MORNING_USERNAME", "jasoncbenn")
logger = logging.getLogger(__name__)
NOTEBOOKLM_BIN = os.getenv("NOTEBOOKLM_BIN", "notebooklm")

SYSTEM_PROMPT = """You are the morning sit companion in the Sit app. Each session is a \
brief check-in around one morning practice, and it has an arc: first, how the user is \
actually feeling — body, energy, mood, what's alive; second, what they want to focus on \
this morning; third, help them translate that into a good routine — a warm-up if the body \
or mind needs one, the kind of sit (guided or unguided), its length, and an intention — \
chosen from the practice library below and offered with propose_program. Then they do it, \
and afterwards they report back. Don't rush the first two beats to get to the third; the \
routine should follow from what they said, not lead it. A marker like "[A 30-minute sit \
happens here, after: Spinal Energy Series, abbreviated (9 min).]" is the user logging the \
routine; everything after it is their post-sit report. When that report sounds complete, \
distill the whole session into a journal entry.

Tone: warm, spare, direct. Plain text only — no markdown headers or bold. One or two short \
paragraphs per reply. You are a fellow traveler with good recall of their practice history, \
not a teacher; ground everything in what they actually said or what the notebook says.

Tools:
- ask_notebooklm queries "Rigdzin", a notebook of the user's dharma teachings. Use it when \
the check-in raises a question the tradition speaks to. Ask one well-formed question. The \
user sees the full answer, so don't quote or summarize it — apply it in a line or two.
- propose_program offers a routine as a card with a start button: warm-ups (by slug), \
the sit component (by slug), and minutes. Use it once the feeling and the focus are clear; \
one proposal, adjusted if they push back, rather than a menu of options. Include the \
intention in the note.
- find_guided_meditations searches the user's own recordings — Rigdzin, Jhourney, Burbea — \
for guided sits that fit what they brought this morning, and shows the matches as a card they \
can play. Phrase the inquiry as the need rather than a title: "settling a scattered anxious \
mind", "grief that wants holding". Recordings heard recently are excluded for you. Reach for \
it in the third beat when a guided sit might serve better than silence, or when they ask for \
one; at most once per turn.
- create_component adds a practice to the library when the user describes one that isn't \
there yet — a stretch sequence, a breathing exercise, a guided sit — with a summary that \
says when to reach for it, so future mornings can suggest it.
- write_journal_entry writes the session's journal entry to the user's wake-up log. Call it \
when the post-sit report feels complete (the user signals completion by tone — summing up, \
"feels complete", a settled report). Title: short and specific, like "30-min sit: excitement \
as weather". Body: markdown bullets ("- ..."), first person from the user's perspective, \
capturing intention, what happened, key findings (bold the load-bearing phrase with **), and \
what to carry forward. Match the voice of the recent entries below. Don't ask permission to \
write it — write it, then confirm in one line.

Today is {today}.

Recent wake-up log entries, newest first, for continuity — reference them naturally:

{recent_entries}"""

UPDATE_CONTEXT = """This session already wrote a journal entry. The conversation above the \
"[wrote journal entry]" marker is what that entry covered; everything after it is a \
continuation. Here is the entry as it currently stands:

{heading}
{body}

If you write again, produce a complete replacement — one entry covering both the original \
conversation and the continuation — and it will overwrite the current entry in place."""

GREETING_INSTRUCTION = """(The user just opened the morning dashboard to begin a session. \
Greet them: in one or two sentences, pick up the thread from their most recent entry — the \
edge or question it ended on — then ask what's alive this morning. Nothing else.)"""

CLOSING_INSTRUCTION = """(The user never returned to this session; it is being closed out \
automatically. Write its journal entry now with write_journal_entry — even unresolved, the \
question or observation is worth keeping. Capture what was alive and where the thread left \
off; don't claim a sit or an outcome that isn't in the conversation, and skip the \
"N-min sit:" title format. Then reply with one short closing line.)"""

INTENTION_INSTRUCTION = """(The user just opened the sit timer. Distill this session's \
intention for the sit — plain text, no preamble, no quotes. If the sit has distinct phases, \
give each phase its own line, separated by a newline — at most 15 words per line, at most \
three lines; otherwise a single short line. If no intention was settled, offer the simplest \
grounding phrase from what's alive this morning.)"""

# Fast first token matters here: the user is looking at the timer screen waiting
# to settle. Fable's always-on thinking would hold the line back for seconds.
INTENTION_MODEL = "claude-sonnet-5"

TOOLS = [
    {
        "name": "ask_notebooklm",
        "description": "Ask the Rigdzin notebook (the user's dharma teachings in NotebookLM) a question. Takes ~1-2 minutes.",
        "input_schema": {
            "type": "object",
            "properties": {"question": {"type": "string"}},
            "required": ["question"],
        },
    },
    {
        "name": "write_journal_entry",
        "description": "Write (or, if this session already wrote one, overwrite) the session's journal entry in the wake-up log.",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Short specific title, e.g. '30-min sit: excitement as weather'"},
                "body": {"type": "string", "description": "Markdown bullet lines, first person"},
            },
            "required": ["title", "body"],
        },
    },
    {
        "name": "create_component",
        "description": "Add a practice to the library — a warm-up, or a guided/unguided sit. It becomes available to propose_program immediately, and stays available on later mornings.",
        "input_schema": {
            "type": "object",
            "properties": {
                "kind": {"type": "string", "enum": ["warmup", "guided", "unguided"]},
                "name": {"type": "string", "description": "Shown in the menu and the sit marker, e.g. 'Spinal Energy Series, abbreviated'"},
                "summary": {"type": "string", "description": "One or two sentences: what it is and when to reach for it. This is what you'll read later."},
                "steps": {
                    "type": "array",
                    "description": "Ordered steps. duration_s null means manual advance in a warm-up, and the chosen sit length in a sit.",
                    "items": {
                        "type": "object",
                        "properties": {
                            "title": {"type": "string"},
                            "text": {"type": "string"},
                            "media": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string", "enum": ["image", "audio", "video"]},
                                    "src": {"type": "string"},
                                },
                                "required": ["type", "src"],
                            },
                            "duration_s": {"type": ["integer", "null"]},
                            "bell": {"type": "string", "enum": ["soft", "long", "none"]},
                        },
                        "required": ["title"],
                    },
                },
            },
            "required": ["kind", "name", "summary", "steps"],
        },
    },
    {
        "name": "propose_program",
        "description": "Offer the user a routine for this morning: warm-ups, then the sit. Shows as a card with a start button — use it instead of describing the routine in prose. Slugs are the bracketed handles in the Practice library section.",
        "input_schema": {
            "type": "object",
            "properties": {
                "warmup_slugs": {"type": "array", "items": {"type": "string"}, "description": "Warm-up slugs from the library, in order. Empty for a bare sit."},
                "sit_slug": {"type": "string", "description": "Slug of the sit component, e.g. 'unguided-sit'"},
                "sit_minutes": {"type": "integer"},
                "note": {"type": "string", "description": "One short clause on why this one, shown on the card."},
            },
            "required": ["sit_minutes"],
        },
    },
    {
        "name": "find_guided_meditations",
        "description": "Search the user's own guided-meditation recordings (Rigdzin, Jhourney, Burbea) for ones that fit what they said this morning. Returns zero to four options, shown to the user as a card they can play. Recently heard recordings are excluded automatically.",
        "input_schema": {
            "type": "object",
            "properties": {
                "inquiry": {"type": "string", "description": "The need in their own terms, not a title, e.g. 'settling a scattered anxious mind' or 'grief that wants holding'."},
                "max_minutes": {"type": "integer", "description": "Optional cap on how long a recording may be."},
            },
            "required": ["inquiry"],
        },
    },
]


class ChatRequest(BaseModel):
    message: str
    timezone: str = "America/Los_Angeles"


class NewSessionRequest(BaseModel):
    timezone: str = "America/Los_Angeles"


def get_user(session: Session) -> User:
    return session.exec(select(User).where(User.username == MORNING_USERNAME)).one()


def serialize_message(m: MorningMessage) -> dict:
    return {
        "id": str(m.id),
        "role": m.role,
        "content": m.content,
        "tool_label": m.tool_label,
        "data": m.data,
        "created_at": m.created_at.isoformat(),
    }


def serialize_session(s: MorningSession) -> dict:
    return {
        "id": str(s.id),
        "created_at": s.created_at.isoformat(),
        "journal_written_at": s.journal_written_at.isoformat() if s.journal_written_at else None,
    }


def build_system_prompt(morning: MorningSession, user_tz: ZoneInfo, session: Session) -> str:
    entries = journal.read_entries(limit=3)
    rendered = "\n\n".join(f"### {e['date']} {e['title']}\n{e['body'].strip()}" for e in entries)
    prompt = SYSTEM_PROMPT.format(
        today=datetime.now(user_tz).strftime("%A, %B %-d, %Y"),
        recent_entries=rendered,
    )
    if morning.journal_heading:
        prompt += "\n\n" + UPDATE_CONTEXT.format(
            heading=morning.journal_heading,
            body=journal.read_entry(morning.journal_heading),
        )
    return prompt + "\n\n" + library.component_index_text(session)


def build_api_messages(db_messages: list[MorningMessage]) -> list[dict]:
    """Flatten stored messages into API turns; tool events become inline markers so the
    model can see where in the conversation the entry was written."""
    api = []
    for m in db_messages:
        if m.role == "tool":
            suffix = recordings.replay_suffix(m.data) if m.data and "choices" in m.data else ""
            content = f"[{m.tool_label}: {m.content}{suffix}]"
            if m.data and m.data.get("answer"):
                content += f"\n[Rigdzin answered: {m.data['answer']}]"
            role = "assistant"
        elif m.role == "sit":
            summary = library.program_summary(m.data["program"]) if m.data else ""
            tail = f", {summary}" if summary else ""
            content = f"[A {m.content}-minute sit happens here{tail}.]"
            role = "assistant"
        else:
            content, role = m.content, m.role
        if api and api[-1]["role"] == role:
            api[-1]["content"] += "\n\n" + content
        else:
            api.append({"role": role, "content": content})
    # Sessions open with an assistant greeting, but the API requires a user turn first.
    if api and api[0]["role"] == "assistant":
        api.insert(0, {"role": "user", "content": "(Session opened.)"})
    return api


CITATION_RE = re.compile(r"\s?\[\d+(?:\s?[-–,]\s?\d+)*\]")


def ask_notebooklm(question: str) -> str:
    try:
        result = subprocess.run(
            [NOTEBOOKLM_BIN, "ask", "--json", question],
            capture_output=True, text=True, timeout=300,
        )
    except subprocess.TimeoutExpired:
        # NotebookLM latency is wildly variable; a slow answer must degrade like a
        # failed one, not kill the SSE turn (which loses the whole morning session).
        logger.error("NotebookLM query timed out after 300s")
        return "(NotebookLM didn't answer in time — go on without it.)"
    if result.returncode != 0:
        err = result.stderr.strip()[-500:]
        logger.error("NotebookLM query failed: %s", err)
        return f"(NotebookLM query failed: {err})"
    answer = CITATION_RE.sub("", json.loads(result.stdout)["answer"])
    # NotebookLM's chat persona signs off with a follow-up offer ("Would you like
    # to…?") that reads as the notebook talking to the user. Drop it.
    paragraphs = answer.strip().split("\n\n")
    if len(paragraphs) > 1 and paragraphs[-1].rstrip().endswith("?"):
        paragraphs.pop()
    return "\n\n".join(paragraphs).strip()


NOTEBOOK_RESULT_NOTE = ("[The full answer above is shown to the user. Don't quote or "
                        "summarize it — apply it: name the one thing from it that matters "
                        "this morning, in a line or two.]")


def write_journal(
    morning: MorningSession, title: str, body: str,
    user_tz: ZoneInfo, session: Session, entry_date: Optional[date] = None,
) -> str:
    """Write or overwrite the session's entry. Returns the tool_label for the UI chip.
    Sits are logged separately, by the explicit add-sit button."""
    heading = journal.make_heading(title, entry_date or datetime.now(user_tz).date())
    if morning.journal_heading:
        journal.update_entry(morning.journal_heading, heading, body)
        morning.journal_heading = heading
        session.add(morning)
        return "Updated journal entry → Wake up.md"

    journal.write_entry(heading, body)
    morning.journal_heading = heading
    morning.journal_written_at = datetime.now(tz.utc)
    session.add(morning)
    return "Wrote journal entry → Wake up.md"


def agent_turn_events(
    morning: MorningSession, user: User,
    user_tz: ZoneInfo, session: Session, greeting: bool = False, closing: bool = False,
):
    """Run the model (with tool loop) over the session's stored messages, persist
    everything new, and yield progress events as they happen:
      {"type": "text", "delta": str}          — assistant tokens
      {"type": "tool_pending", "name": str}   — model started emitting a tool call
      {"type": "tool", ...}                   — tool about to run (label + input known)
      {"type": "tool_done", "message": dict}  — tool ran; persisted chip message
      {"type": "done", "messages": [...], "journal_written": bool}  — always last
    closing mode (abandoned thread): the entry is dated to the session's day."""
    db_messages = session.exec(
        select(MorningMessage)
        .where(MorningMessage.session_id == morning.id)
        .order_by(MorningMessage.created_at)
    ).all()
    api_messages = build_api_messages(db_messages)
    if greeting:
        api_messages.append({"role": "user", "content": GREETING_INSTRUCTION})
    if closing:
        api_messages.append({"role": "user", "content": CLOSING_INSTRUCTION})

    system_prompt = build_system_prompt(morning, user_tz, session)
    client = anthropic.Anthropic()
    new_messages: list[MorningMessage] = []
    journal_written = False
    searched_guided = False

    for _ in range(6):
        # Fable: thinking is always on and counts toward max_tokens; fallbacks
        # reroute a safety refusal to Opus server-side so a turn never comes
        # back empty (extra_body: the 0.125 SDK has no typed fallbacks param).
        with client.beta.messages.stream(
            model=MODEL,
            max_tokens=8000,
            system=system_prompt,
            messages=api_messages,
            tools=TOOLS,
            betas=["server-side-fallback-2026-07-01"],
            extra_body={"fallbacks": "default"},
        ) as stream:
            for event in stream:
                if event.type == "content_block_delta" and event.delta.type == "text_delta":
                    yield {"type": "text", "delta": event.delta.text}
                elif event.type == "content_block_start" \
                        and event.content_block.type == "tool_use":
                    yield {"type": "tool_pending", "name": event.content_block.name}
            response = stream.get_final_message()

        text = "".join(block.text for block in response.content if block.type == "text")
        if text.strip():
            assistant_msg = MorningMessage(session_id=morning.id, role="assistant", content=text)
            session.add(assistant_msg)
            new_messages.append(assistant_msg)

        if response.stop_reason != "tool_use":
            break

        # Replay the full content (thinking blocks included — the API requires them
        # unchanged when continuing a tool loop on the same model). Needs anthropic
        # >= 0.125: older SDKs mis-accumulate streamed thinking blocks.
        api_messages.append({"role": "assistant", "content": response.content})
        tool_results = []
        for block in response.content:
            if block.type != "tool_use":
                continue
            if block.name == "ask_notebooklm":
                question = block.input["question"]
                yield {"type": "tool", "tool_label": "Asking Rigdzin notebook…", "content": question}
                answer = ask_notebooklm(question)
                tool_msg = MorningMessage(
                    session_id=morning.id, role="tool",
                    content=question, tool_label="Asked Rigdzin notebook",
                    data={"answer": answer},
                )
                result_text = f"{answer}\n\n{NOTEBOOK_RESULT_NOTE}"
            elif block.name == "create_component":
                name = block.input["name"]
                yield {"type": "tool", "tool_label": "Adding to library…", "content": name}
                component = library.create_component(
                    session, kind=block.input["kind"], name=name,
                    summary=block.input["summary"], steps=block.input["steps"],
                    source="llm",
                )
                tool_msg = MorningMessage(
                    session_id=morning.id, role="tool",
                    content=component.summary, tool_label=f"Added to library: {component.name}",
                )
                result_text = f"Added to the library as \"{component.slug}\"."
                # The index in the system prompt is now stale; rebuild it so the
                # model can propose the new component in this same turn.
                system_prompt = build_system_prompt(morning, user_tz, session)
            elif block.name == "propose_program":
                sit_minutes = block.input["sit_minutes"]
                # Unknown slugs raise here, before anything is persisted.
                program = library.build_program(
                    session,
                    block.input.get("warmup_slugs", []),
                    block.input.get("sit_slug", "unguided-sit"),
                    sit_minutes,
                )
                line = library.program_line(program, block.input.get("note", ""))
                yield {"type": "tool", "tool_label": "Proposing routine…", "content": line}
                tool_msg = MorningMessage(
                    session_id=morning.id, role="tool",
                    content=line, tool_label="Proposed routine",
                    data={
                        "warmup_slugs": block.input.get("warmup_slugs", []),
                        "sit_slug": block.input.get("sit_slug", "unguided-sit"),
                        "sit_minutes": sit_minutes,
                        "note": block.input.get("note", ""),
                    },
                )
                result_text = ("Proposal shown to the user as a card with a start button. "
                               "Don't repeat it in prose — say at most one short line.")
            elif block.name == "find_guided_meditations":
                inquiry = block.input["inquiry"]
                if searched_guided:
                    # A second card in one turn buries the first and spends
                    # another selector call to say much the same thing.
                    tool_msg = None
                    result_text = "Already searched this turn; work with the options shown."
                else:
                    searched_guided = True
                    yield {"type": "tool", "tool_label": "Searching guided meditations…", "content": inquiry}
                    choices = recordings.find(
                        session, inquiry, max_minutes=block.input.get("max_minutes"),
                    )
                    tool_msg = MorningMessage(
                        session_id=morning.id, role="tool",
                        content=inquiry, tool_label="Guided meditation options",
                        data={"choices": choices, "played": None},
                    )
                    result_text = recordings.tool_result_text(choices)
            else:
                title = block.input["title"]
                if closing:
                    created = morning.created_at if morning.created_at.tzinfo \
                        else morning.created_at.replace(tzinfo=tz.utc)
                    entry_date = created.astimezone(user_tz).date()
                else:
                    entry_date = None
                label = write_journal(
                    morning, title, block.input["body"],
                    user_tz, session, entry_date=entry_date,
                )
                tool_msg = MorningMessage(
                    session_id=morning.id, role="tool",
                    content=title, tool_label=label,
                )
                result_text = "Journal entry written."
                journal_written = True
                # Entry now exists on disk; keep the system prompt consistent
                # for any further loop iterations.
                system_prompt = build_system_prompt(morning, user_tz, session)
            if tool_msg is not None:   # a refused repeat persists nothing
                session.add(tool_msg)
                new_messages.append(tool_msg)
                yield {"type": "tool_done", "message": serialize_message(tool_msg)}
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": result_text,
            })
        api_messages.append({"role": "user", "content": tool_results})

    session.commit()
    for m in new_messages:
        session.refresh(m)
    yield {
        "type": "done",
        "messages": [serialize_message(m) for m in new_messages],
        "journal_written": journal_written,
    }


def run_agent_turn(*args, **kwargs) -> tuple[list[dict], bool]:
    """Non-streaming wrapper: drain the event stream, return the final result."""
    for event in agent_turn_events(*args, **kwargs):
        pass
    return event["messages"], event["journal_written"]


@router.get("/sessions")
def list_sessions(session: Session = Depends(get_session)):
    user = get_user(session)
    sessions = session.exec(
        select(MorningSession)
        .where(MorningSession.user_id == user.id)
        .order_by(MorningSession.created_at)
    ).all()
    return {"sessions": [serialize_session(s) for s in sessions]}


@router.post("/sessions")
def create_session(body: NewSessionRequest, session: Session = Depends(get_session)):
    """Server-sent events, same shape as /chat, preceded by a "session" event —
    so the greeting streams instead of arriving whole after the full model turn."""
    user = get_user(session)
    morning = MorningSession(user_id=user.id)
    session.add(morning)
    session.commit()
    morning_id = morning.id

    def sse():
        # The request-scoped session is torn down before a StreamingResponse body
        # runs, so the generator opens its own.
        with Session(engine) as stream_session:
            morning = stream_session.get(MorningSession, morning_id)
            yield "data: " + json.dumps(
                {"type": "session", "session": serialize_session(morning)}
            ) + "\n\n"
            for event in agent_turn_events(
                morning=morning,
                user=get_user(stream_session),
                user_tz=ZoneInfo(body.timezone),
                session=stream_session,
                greeting=True,
            ):
                yield "data: " + json.dumps(event) + "\n\n"

    return StreamingResponse(
        sse(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/sessions/{session_id}/messages")
def get_messages(session_id: UUID, session: Session = Depends(get_session)):
    messages = session.exec(
        select(MorningMessage)
        .where(MorningMessage.session_id == session_id)
        .order_by(MorningMessage.created_at)
    ).all()
    return {"messages": [serialize_message(m) for m in messages]}


@router.post("/sessions/{session_id}/chat")
def chat(session_id: UUID, body: ChatRequest, session: Session = Depends(get_session)):
    """Server-sent events: text deltas and tool calls as they happen, then a final
    "done" event with the persisted messages."""
    morning = session.get(MorningSession, session_id)
    user_msg = MorningMessage(session_id=morning.id, role="user", content=body.message)
    session.add(user_msg)
    session.commit()

    def sse():
        # The request-scoped session is torn down before a StreamingResponse body
        # runs, so the generator opens its own.
        with Session(engine) as stream_session:
            for event in agent_turn_events(
                morning=stream_session.get(MorningSession, session_id),
                user=get_user(stream_session),
                user_tz=ZoneInfo(body.timezone),
                session=stream_session,
            ):
                yield "data: " + json.dumps(event) + "\n\n"

    return StreamingResponse(
        sse(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/sessions/{session_id}/intention")
def intention(
    session_id: UUID,
    before: Optional[UUID] = None,
    timezone: str = "America/Los_Angeles",
):
    """Stream a one-line intention for the timer overlay, distilled from the
    conversation up to the sit marker (`before`) — so reopening the timer after
    post-sit chat still reflects what the sit was actually about."""
    def sse():
        with Session(engine) as stream_session:
            morning = stream_session.get(MorningSession, session_id)
            db_messages = stream_session.exec(
                select(MorningMessage)
                .where(MorningMessage.session_id == session_id)
                .order_by(MorningMessage.created_at)
            ).all()
            if before is not None:
                idx = next((i for i, m in enumerate(db_messages) if m.id == before), None)
                if idx is not None:
                    db_messages = db_messages[:idx]
            api_messages = build_api_messages(db_messages)
            api_messages.append({"role": "user", "content": INTENTION_INSTRUCTION})
            client = anthropic.Anthropic()
            with client.messages.stream(
                model=INTENTION_MODEL,
                max_tokens=100,
                system=build_system_prompt(morning, ZoneInfo(timezone), stream_session),
                messages=api_messages,
            ) as stream:
                for text in stream.text_stream:
                    yield "data: " + json.dumps({"type": "text", "delta": text}) + "\n\n"
        yield 'data: {"type": "done"}\n\n'

    return StreamingResponse(
        sse(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


class NewComponentRequest(BaseModel):
    kind: str  # warmup | guided | unguided
    name: str
    summary: str
    steps: list[dict]
    slug: Optional[str] = None


@router.get("/components")
def list_components(session: Session = Depends(get_session)):
    return {"components": [library.serialize_component(c) for c in library.list_components(session)]}


@router.post("/components")
def create_component(body: NewComponentRequest, session: Session = Depends(get_session)):
    """Hand-authored practice; same code path the create_component tool uses."""
    component = library.create_component(
        session, kind=body.kind, name=body.name, summary=body.summary,
        steps=body.steps, source="user", slug=body.slug,
    )
    session.commit()
    session.refresh(component)
    return {"component": library.serialize_component(component)}


class AddSitRequest(BaseModel):
    sit_minutes: int
    timezone: str = "America/Los_Angeles"
    warmup_slugs: list[str] = []
    sit_slug: str = "unguided-sit"


@router.post("/sessions/{session_id}/sits")
def add_sit(session_id: UUID, body: AddSitRequest, session: Session = Depends(get_session)):
    """The user declares a sit is happening: log it and pin a sit marker message into
    the conversation, splitting pre-sit chat from post-sit reflections. No model turn."""
    user = get_user(session)
    morning = session.get(MorningSession, session_id)
    now = datetime.now(tz.utc)

    # A backfilled sit today (date known, time nominal) is a placeholder for this
    # moment: the exact-time sit replaces it rather than double-counting the day.
    # Sits that already have real times stay — a second sit in a day is legitimate.
    user_tz = ZoneInfo(body.timezone)
    day_start, day_end = _local_day_bounds(now.astimezone(user_tz).date().isoformat(), user_tz)
    placeholders = session.exec(
        select(Sit).where(
            Sit.user_id == user.id,
            Sit.time_known == False,  # noqa: E712
            Sit.started_at >= day_start,
            Sit.started_at < day_end,
        )
    ).all()
    if placeholders:
        ids = [s.id for s in placeholders]
        for m in session.exec(
            select(MorningSession).where(MorningSession.sit_id.in_(ids))
        ).all():
            m.sit_id = None
            session.add(m)
        for s in placeholders:
            session.delete(s)

    # Resolved now and snapshotted on both rows: a later edit to a component
    # never changes what this morning played.
    program = library.build_program(
        session, body.warmup_slugs, body.sit_slug, body.sit_minutes,
    )
    sit = Sit(
        user_id=user.id,
        duration_seconds=float(body.sit_minutes * 60),
        started_at=now,
        timezone=body.timezone,
        program_json=program,
    )
    session.add(sit)
    session.flush()
    morning.sit_id = sit.id
    session.add(morning)
    msg = MorningMessage(
        session_id=morning.id, role="sit",
        content=str(body.sit_minutes), data={"program": program},
    )
    session.add(msg)
    session.commit()
    session.refresh(msg)
    return {"message": serialize_message(msg)}


class ListenRequest(BaseModel):
    recording_id: str
    message_id: Optional[UUID] = None


@router.post("/sessions/{session_id}/listens")
def add_listen(session_id: UUID, body: ListenRequest, session: Session = Depends(get_session)):
    """The user pressed play on a guided recording: log it so search stops offering
    it for a month, and mark the card it came from so it reads as played."""
    session.add(Listen(
        session_id=session_id, recording_id=body.recording_id,
        started_at=datetime.now(tz.utc),
    ))
    # Stamp the card they actually pressed play on; scrolling back and playing an
    # older one shouldn't mark today's options. The player outlives its card, so
    # without an id fall back to the latest — and there isn't always one.
    if body.message_id:
        options = session.get(MorningMessage, body.message_id)
    else:
        options = session.exec(
            select(MorningMessage)
            .where(
                MorningMessage.session_id == session_id,
                MorningMessage.tool_label == "Guided meditation options",
            )
            .order_by(MorningMessage.created_at.desc())
        ).first()
    if options:
        options.data = dict(options.data, played=body.recording_id)
        session.add(options)
    session.commit()
    return {"ok": True}


STALE_AFTER = timedelta(hours=24)


@router.post("/close-stale")
def close_stale(body: NewSessionRequest, session: Session = Depends(get_session)):
    """Close out abandoned threads: any session where the user said something, no
    journal entry was written, and nothing has happened for 24h gets its entry
    written for it (unresolved is fine — the question is still worth noting)."""
    user = get_user(session)
    cutoff = datetime.now(tz.utc) - STALE_AFTER
    closed = []
    candidates = session.exec(
        select(MorningSession).where(
            MorningSession.user_id == user.id,
            MorningSession.journal_written_at == None,  # noqa: E711
        )
    ).all()
    for morning in candidates:
        messages = session.exec(
            select(MorningMessage).where(MorningMessage.session_id == morning.id)
        ).all()
        if not any(m.role == "user" for m in messages):
            continue  # greeting-only session; nothing worth journaling
        last = max(m.created_at for m in messages)
        if last.tzinfo is None:
            last = last.replace(tzinfo=tz.utc)
        if last > cutoff:
            continue
        _, journal_written = run_agent_turn(
            morning, user, user_tz=ZoneInfo(body.timezone),
            session=session, closing=True,
        )
        closed.append({"session_id": str(morning.id), "journal_written": journal_written})
    return {"closed": closed}


@router.get("/journal")
def get_journal(limit: Optional[int] = None):
    return {"entries": journal.read_entries(limit=limit)}


class ToggleSitRequest(BaseModel):
    date: str  # YYYY-MM-DD, local
    sit_minutes: int = 30
    timezone: str = "America/Los_Angeles"


def _local_day_bounds(date_str: str, tz: ZoneInfo) -> tuple[datetime, datetime]:
    day_start = datetime.fromisoformat(date_str).replace(tzinfo=tz)
    return day_start, day_start + timedelta(days=1)


@router.get("/sits")
def list_sits(
    start: str,
    end: str,
    timezone: str = "America/Los_Angeles",
    session: Session = Depends(get_session),
):
    """Minutes sat per local date within [start, end], for the calendar widget."""
    user = get_user(session)
    user_tz = ZoneInfo(timezone)
    range_start, _ = _local_day_bounds(start, user_tz)
    _, range_end = _local_day_bounds(end, user_tz)
    sits = session.exec(
        select(Sit).where(
            Sit.user_id == user.id,
            Sit.started_at >= range_start,
            Sit.started_at < range_end,
        )
    ).all()
    days: dict[str, int] = {}
    for s in sits:
        started = s.started_at if s.started_at.tzinfo else s.started_at.replace(tzinfo=tz.utc)
        d = started.astimezone(user_tz).date().isoformat()
        days[d] = days.get(d, 0) + round(s.duration_seconds / 60)
    return {"days": days}


@router.post("/sits/toggle")
def toggle_sit(body: ToggleSitRequest, session: Session = Depends(get_session)):
    """Backfill helper: tap a day to declare/undeclare a sit. A day with any sits
    is cleared; an empty day gets one sit of the given length, nominally 8am."""
    user = get_user(session)
    user_tz = ZoneInfo(body.timezone)
    day_start, day_end = _local_day_bounds(body.date, user_tz)
    sits = session.exec(
        select(Sit).where(
            Sit.user_id == user.id,
            Sit.started_at >= day_start,
            Sit.started_at < day_end,
        )
    ).all()
    if sits:
        sit_ids = [s.id for s in sits]
        for m in session.exec(
            select(MorningSession).where(MorningSession.sit_id.in_(sit_ids))
        ).all():
            m.sit_id = None
            session.add(m)
        for s in sits:
            session.delete(s)
        session.commit()
        return {"date": body.date, "minutes": 0}

    sit = Sit(
        user_id=user.id,
        duration_seconds=float(body.sit_minutes * 60),
        started_at=day_start.replace(hour=8).astimezone(tz.utc),
        timezone=body.timezone,
        time_known=False,
    )
    session.add(sit)
    session.commit()
    return {"date": body.date, "minutes": body.sit_minutes}
