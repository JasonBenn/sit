import json
import os
from datetime import datetime
from typing import Optional
from uuid import UUID
from zoneinfo import ZoneInfo
from pydantic import BaseModel
import anthropic
from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from app.db import get_session
from app.auth import get_current_user
from app.models import User, Flow, Sit, Checkin, ChatMessage

router = APIRouter(prefix="/api/chat", tags=["chat"])

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

SYSTEM_PROMPT_TEMPLATE = """You are a meditation practice assistant for the Sit app.

The user tracks their meditation practice in two ways:
1. Through seated practice.
2. Through random check-ins throughout the day.

You can query their practice data to help them understand patterns and progress.

Be warm but concise. Don't offer advice proactively - you're a data assistant, not the meditation teacher. Do point out trends if you notice them.

EXAMPLE QUERY: "How long have I been sitting recently?"
BAD: "80m. If you're looking to enhance your meditation practice..."
GOOD: "Here are your timed sits this week:
- 2/16 Mon 9:00am: 30m
- 2/18 Wed 8:35am: 20m
- 2/20 Fri 8:45am: 30m
1h20m total in the last week. That's 25% more than the previous week, nicely done."

Respond in plain text, don't use **markdown formatting**, but newlines and bullets are ok.

Today's date is {today}. All timestamps in query results are in the user's local time ({timezone})."""

QUERY_TOOL = {
    "name": "query_practice_data",
    "description": "Query the user's meditation practice data. Returns sits (timed seated meditation with duration_seconds) and/or checkins (flow-based check-ins with steps and optional voice note transcriptions).",
    "input_schema": {
        "type": "object",
        "properties": {
            "start_date": {
                "type": "string",
                "description": "Start date filter (ISO format, e.g. 2026-01-01). Optional.",
            },
            "end_date": {
                "type": "string",
                "description": "End date filter (ISO format). Optional.",
            },
            "type": {
                "type": "string",
                "enum": ["sits", "checkins", "all"],
                "description": "Type of practice data to query. 'sits' for timed meditation sessions, 'checkins' for flow-based check-ins, 'all' for both. Defaults to 'all'.",
            },
        },
    },
}


class ChatRequest(BaseModel):
    message: str
    timezone: str = "UTC"


class ChatMessageResponse(BaseModel):
    id: UUID
    role: str
    content: str
    created_at: datetime


def query_practice_data(
    user_id: UUID,
    session: Session,
    tz: ZoneInfo,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    type: Optional[str] = "all",
) -> dict:
    results = []

    include_sits = type in ("sits", "all", None)
    include_checkins = type in ("checkins", "all", None)

    if include_sits:
        sit_stmt = (
            select(Sit).where(Sit.user_id == user_id).order_by(Sit.started_at.desc())
        )
        if start_date:
            local_start = datetime.fromisoformat(start_date).replace(tzinfo=tz)
            sit_stmt = sit_stmt.where(
                Sit.started_at
                >= local_start.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
            )
        if end_date:
            local_end = datetime.fromisoformat(end_date).replace(
                hour=23, minute=59, second=59, tzinfo=tz
            )
            sit_stmt = sit_stmt.where(
                Sit.started_at
                <= local_end.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
            )
        sits = session.exec(sit_stmt).all()
        for s in sits:
            local_time = (
                s.started_at.replace(tzinfo=ZoneInfo("UTC")).astimezone(tz).isoformat()
            )
            results.append(
                {
                    "type": "sit",
                    "time": local_time,
                    "duration_seconds": s.duration_seconds,
                }
            )

    if include_checkins:
        checkin_stmt = (
            select(Checkin)
            .where(Checkin.user_id == user_id)
            .order_by(Checkin.responded_at.desc())
        )
        if start_date:
            local_start = datetime.fromisoformat(start_date).replace(tzinfo=tz)
            checkin_stmt = checkin_stmt.where(
                Checkin.responded_at
                >= local_start.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
            )
        if end_date:
            local_end = datetime.fromisoformat(end_date).replace(
                hour=23, minute=59, second=59, tzinfo=tz
            )
            checkin_stmt = checkin_stmt.where(
                Checkin.responded_at
                <= local_end.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
            )
        checkins = session.exec(checkin_stmt).all()

        # Batch-fetch flow definitions
        flow_ids = {c.flow_id for c in checkins if c.flow_id}
        flows = (
            session.exec(select(Flow).where(Flow.id.in_(flow_ids))).all()
            if flow_ids
            else []
        )
        flows_map = {str(f.id): {"name": f.name, "steps": f.steps_json} for f in flows}

        for c in checkins:
            local_time = (
                c.responded_at.replace(tzinfo=ZoneInfo("UTC"))
                .astimezone(tz)
                .isoformat()
            )
            results.append(
                {
                    "type": "checkin",
                    "time": local_time,
                    "flow_id": str(c.flow_id) if c.flow_id else None,
                    "steps": c.steps,
                    "transcription": c.transcription,
                }
            )
    else:
        flows_map = {}

    # Sort merged results by time descending
    results.sort(key=lambda r: r["time"], reverse=True)

    return {
        "flows": flows_map,
        "responses": results,
        "total_count": len(results),
    }


@router.post("")
def chat(
    body: ChatRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    tz = ZoneInfo(body.timezone)
    now_local = datetime.now(tz)
    system_prompt = SYSTEM_PROMPT_TEMPLATE.format(
        today=now_local.strftime("%A, %B %-d, %Y"),
        timezone=body.timezone,
    )

    # Save user message
    user_msg = ChatMessage(user_id=user.id, role="user", content=body.message)
    session.add(user_msg)
    session.flush()

    # Load recent history for context
    history = session.exec(
        select(ChatMessage)
        .where(ChatMessage.user_id == user.id)
        .order_by(ChatMessage.created_at.desc())
        .limit(20)
    ).all()
    history.reverse()

    messages = []
    for msg in history:
        messages.append({"role": msg.role, "content": msg.content})

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=system_prompt,
        messages=messages,
        tools=[QUERY_TOOL],
    )

    # Handle tool use
    if response.stop_reason == "tool_use":
        # Build assistant message with all content blocks
        messages.append({"role": "assistant", "content": response.content})

        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                args = block.input
                result = query_practice_data(
                    user.id,
                    session,
                    tz,
                    args.get("start_date"),
                    args.get("end_date"),
                    args.get("type", "all"),
                )
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result),
                    }
                )

        messages.append({"role": "user", "content": tool_results})

        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=system_prompt,
            messages=messages,
            tools=[QUERY_TOOL],
        )

    assistant_content = ""
    for block in response.content:
        if hasattr(block, "text"):
            assistant_content += block.text

    # Save assistant message
    assistant_msg = ChatMessage(
        user_id=user.id, role="assistant", content=assistant_content
    )
    session.add(assistant_msg)
    session.commit()
    session.refresh(assistant_msg)

    return {
        "id": str(assistant_msg.id),
        "role": assistant_msg.role,
        "content": assistant_msg.content,
        "created_at": assistant_msg.created_at.isoformat(),
    }


@router.get("/history", response_model=list[ChatMessageResponse])
def get_chat_history(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    messages = session.exec(
        select(ChatMessage)
        .where(ChatMessage.user_id == user.id)
        .order_by(ChatMessage.created_at.desc())
        .limit(50)
    ).all()
    messages.reverse()
    return messages
