"""Morning sit dashboard: session-scoped check-in conversations with two tools —
ask the Rigdzin NotebookLM notebook, and write/update a wake-up log journal entry.

No auth: this router is only reachable over Tailscale (the public vhost 404s it).
"""
import json
import os
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

from app import journal
from app.db import engine, get_session
from app.models import MorningMessage, MorningSession, Sit, User

router = APIRouter(prefix="/api/morning", tags=["morning"])

MODEL = "claude-sonnet-5"
MORNING_USERNAME = os.getenv("MORNING_USERNAME", "jasoncbenn")
NOTEBOOKLM_BIN = os.getenv("NOTEBOOKLM_BIN", "notebooklm")

SYSTEM_PROMPT = """You are the morning sit companion in the Sit app. Each session is a \
brief check-in around one seated meditation: the user shares what's alive before sitting, \
you help them settle on an intention, they sit, and afterwards they report back. A marker \
like "[A 30-minute sit happens here.]" in the conversation is the user logging their sit; \
everything after it is their post-sit report. When that report sounds complete, distill \
the whole session into a journal entry.

Tone: warm, spare, direct. Plain text only — no markdown headers or bold. One or two short \
paragraphs per reply. You are a fellow traveler with good recall of their practice history, \
not a teacher; ground everything in what they actually said or what the notebook says.

Tools:
- ask_notebooklm queries "Rigdzin", a notebook of the user's dharma teachings. Use it when \
the check-in raises a question the tradition speaks to. Ask one well-formed question; weave \
the answer into your reply in your own words.
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
        "created_at": m.created_at.isoformat(),
    }


def serialize_session(s: MorningSession, message_count: int) -> dict:
    return {
        "id": str(s.id),
        "created_at": s.created_at.isoformat(),
        "journal_written_at": s.journal_written_at.isoformat() if s.journal_written_at else None,
        "message_count": message_count,
    }


def build_system_prompt(morning: MorningSession, user_tz: ZoneInfo) -> str:
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
    return prompt


def build_api_messages(db_messages: list[MorningMessage]) -> list[dict]:
    """Flatten stored messages into API turns; tool events become inline markers so the
    model can see where in the conversation the entry was written."""
    api = []
    for m in db_messages:
        if m.role == "tool":
            content = f"[{m.tool_label}: {m.content}]"
            role = "assistant"
        elif m.role == "sit":
            content = f"[A {m.content}-minute sit happens here.]"
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


def ask_notebooklm(question: str) -> str:
    result = subprocess.run(
        [NOTEBOOKLM_BIN, "ask", "--json", question],
        capture_output=True, text=True, timeout=180,
    )
    if result.returncode != 0:
        return f"(NotebookLM query failed: {result.stderr.strip()[-500:]})"
    return json.loads(result.stdout)["answer"]


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

    system_prompt = build_system_prompt(morning, user_tz)
    client = anthropic.Anthropic()
    new_messages: list[MorningMessage] = []
    journal_written = False

    for _ in range(6):
        with client.messages.stream(
            model=MODEL,
            max_tokens=2000,
            system=system_prompt,
            messages=api_messages,
            tools=TOOLS,
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
                tool_msg = MorningMessage(
                    session_id=morning.id, role="tool",
                    content=question, tool_label="Asked Rigdzin notebook",
                )
                result_text = ask_notebooklm(question)
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
                system_prompt = build_system_prompt(morning, user_tz)
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
    counts = {
        s.id: len(session.exec(
            select(MorningMessage.id).where(MorningMessage.session_id == s.id)
        ).all())
        for s in sessions
    }
    return {"sessions": [serialize_session(s, counts[s.id]) for s in sessions]}


@router.post("/sessions")
def create_session(body: NewSessionRequest, session: Session = Depends(get_session)):
    user = get_user(session)
    morning = MorningSession(user_id=user.id)
    session.add(morning)
    session.flush()
    new_messages, _ = run_agent_turn(
        morning, user, user_tz=ZoneInfo(body.timezone),
        session=session, greeting=True,
    )
    return {
        "session": serialize_session(morning, len(new_messages)),
        "messages": new_messages,
    }


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


class AddSitRequest(BaseModel):
    sit_minutes: int
    timezone: str = "America/Los_Angeles"


@router.post("/sessions/{session_id}/sits")
def add_sit(session_id: UUID, body: AddSitRequest, session: Session = Depends(get_session)):
    """The user declares a sit is happening: log it and pin a sit marker message into
    the conversation, splitting pre-sit chat from post-sit reflections. No model turn."""
    user = get_user(session)
    morning = session.get(MorningSession, session_id)
    sit = Sit(
        user_id=user.id,
        duration_seconds=float(body.sit_minutes * 60),
        started_at=datetime.now(tz.utc),
        timezone=body.timezone,
    )
    session.add(sit)
    session.flush()
    morning.sit_id = sit.id
    session.add(morning)
    msg = MorningMessage(session_id=morning.id, role="sit", content=str(body.sit_minutes))
    session.add(msg)
    session.commit()
    session.refresh(msg)
    return {"message": serialize_message(msg)}


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
    )
    session.add(sit)
    session.commit()
    return {"date": body.date, "minutes": body.sit_minutes}
