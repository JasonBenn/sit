"""Morning sit dashboard: session-scoped check-in conversations with two tools —
ask the Rigdzin NotebookLM notebook, and write/update a wake-up log journal entry.

No auth: this router is only reachable over Tailscale (the public vhost 404s it).
"""
import json
import os
import subprocess
from datetime import datetime, timedelta, timezone as tz
from typing import Optional
from uuid import UUID
from zoneinfo import ZoneInfo

import anthropic
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app import journal
from app.db import get_session
from app.models import MorningMessage, MorningSession, Sit, User

router = APIRouter(prefix="/api/morning", tags=["morning"])

MODEL = "claude-sonnet-5"
MORNING_USERNAME = os.getenv("MORNING_USERNAME", "jasoncbenn")
NOTEBOOKLM_BIN = os.getenv("NOTEBOOKLM_BIN", "notebooklm")

SYSTEM_PROMPT = """You are the morning sit companion in the Sit app. Each session is a \
brief check-in around one seated meditation: the user shares what's alive before sitting, \
you help them settle on an intention, they sit, and afterwards they report back. When their \
after-report sounds complete, distill the whole session into a journal entry.

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
        "description": "Write (or, if this session already wrote one, overwrite) the session's journal entry in the wake-up log. Also logs the sit duration.",
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
    sit_minutes: int = 30
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
    morning: MorningSession, user: User, title: str, body: str,
    sit_minutes: int, user_tz: ZoneInfo, session: Session,
) -> str:
    """Write or overwrite the session's entry; log the sit on first write.
    Returns the tool_label for the UI chip."""
    heading = journal.make_heading(title, datetime.now(user_tz).date())
    if morning.journal_heading:
        journal.update_entry(morning.journal_heading, heading, body)
        morning.journal_heading = heading
        session.add(morning)
        return "Updated journal entry → Wake up.md"

    journal.write_entry(heading, body)
    now = datetime.now(tz.utc)
    sit = Sit(
        user_id=user.id,
        duration_seconds=float(sit_minutes * 60),
        started_at=now - timedelta(minutes=sit_minutes),
        timezone=str(user_tz),
    )
    session.add(sit)
    session.flush()
    morning.journal_heading = heading
    morning.journal_written_at = now
    morning.sit_id = sit.id
    session.add(morning)
    return f"Wrote journal entry → Wake up.md · logged {sit_minutes}-min sit"


def run_agent_turn(
    morning: MorningSession, user: User, sit_minutes: int,
    user_tz: ZoneInfo, session: Session, greeting: bool = False,
) -> tuple[list[MorningMessage], bool]:
    """Run the model (with tool loop) over the session's stored messages and persist
    everything new. Returns (new messages, whether a journal entry was written)."""
    db_messages = session.exec(
        select(MorningMessage)
        .where(MorningMessage.session_id == morning.id)
        .order_by(MorningMessage.created_at)
    ).all()
    api_messages = build_api_messages(db_messages)
    if greeting:
        api_messages.append({"role": "user", "content": GREETING_INSTRUCTION})

    system_prompt = build_system_prompt(morning, user_tz)
    client = anthropic.Anthropic()
    new_messages: list[MorningMessage] = []
    journal_written = False

    for _ in range(6):
        response = client.messages.create(
            model=MODEL,
            max_tokens=2000,
            system=system_prompt,
            messages=api_messages,
            tools=TOOLS,
        )
        if response.stop_reason != "tool_use":
            break

        api_messages.append({"role": "assistant", "content": response.content})
        tool_results = []
        for block in response.content:
            if block.type != "tool_use":
                continue
            if block.name == "ask_notebooklm":
                question = block.input["question"]
                tool_msg = MorningMessage(
                    session_id=morning.id, role="tool",
                    content=question, tool_label="Asked Rigdzin notebook",
                )
                result_text = ask_notebooklm(question)
            else:
                title = block.input["title"]
                label = write_journal(
                    morning, user, title, block.input["body"],
                    sit_minutes, user_tz, session,
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
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": result_text,
            })
        api_messages.append({"role": "user", "content": tool_results})

    text = "".join(block.text for block in response.content if hasattr(block, "text"))
    assistant_msg = MorningMessage(session_id=morning.id, role="assistant", content=text)
    session.add(assistant_msg)
    new_messages.append(assistant_msg)
    session.commit()
    for m in new_messages:
        session.refresh(m)
    return new_messages, journal_written


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
        morning, user, sit_minutes=30, user_tz=ZoneInfo(body.timezone),
        session=session, greeting=True,
    )
    return {
        "session": serialize_session(morning, len(new_messages)),
        "messages": [serialize_message(m) for m in new_messages],
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
    user = get_user(session)
    morning = session.get(MorningSession, session_id)
    user_msg = MorningMessage(session_id=morning.id, role="user", content=body.message)
    session.add(user_msg)
    session.flush()
    new_messages, journal_written = run_agent_turn(
        morning, user, sit_minutes=body.sit_minutes,
        user_tz=ZoneInfo(body.timezone), session=session,
    )
    return {
        "messages": [serialize_message(m) for m in new_messages],
        "journal_written": journal_written,
    }


@router.get("/journal")
def get_journal(limit: int = 10):
    return {"entries": journal.read_entries(limit=limit)}
