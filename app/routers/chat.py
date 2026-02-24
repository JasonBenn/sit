import json
import os
from datetime import datetime
from typing import Optional
from uuid import UUID
from zoneinfo import ZoneInfo
from pydantic import BaseModel
import openai
from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from app.db import get_session
from app.auth import get_current_user
from app.models import User, Flow, PromptResponse, ChatMessage

router = APIRouter(prefix="/api/chat", tags=["chat"])

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

SYSTEM_PROMPT_TEMPLATE = """You are a meditation practice assistant for the Sit app. 

The user tracks their meditation practice in two ways: 
1. Through seated practice.
2. Through random check-ins throughout the day.

You can query their practice data to help them understand patterns and progress. 

Be warm, insightful, and concise. 

Respond in plain text only. No **markdown styles**, no bullet points, no formatting.

Today's date is {today}. All timestamps in query results are in the user's local time ({timezone})."""

QUERY_TOOL = {
    "type": "function",
    "function": {
        "name": "query_practice_data",
        "description": "Query the user's meditation practice data. Returns two types of entries: 'timer' (timed seated meditation with duration_seconds) and 'check-in' (flow-based check-ins with steps and optional voice note transcriptions).",
        "parameters": {
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
) -> dict:
    stmt = (
        select(PromptResponse)
        .where(PromptResponse.user_id == user_id)
        .order_by(PromptResponse.responded_at.desc())
    )
    if start_date:
        # Convert local date to UTC for DB query (start of day in user's timezone)
        local_start = datetime.fromisoformat(start_date).replace(tzinfo=tz)
        stmt = stmt.where(
            PromptResponse.responded_at
            >= local_start.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
        )
    if end_date:
        # End of day in user's timezone, converted to UTC
        local_end = datetime.fromisoformat(end_date).replace(
            hour=23, minute=59, second=59, tzinfo=tz
        )
        stmt = stmt.where(
            PromptResponse.responded_at
            <= local_end.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
        )

    responses = session.exec(stmt).all()

    # Collect unique flow IDs and batch-fetch definitions
    flow_ids = {r.flow_id for r in responses if r.flow_id}
    flows = (
        session.exec(select(Flow).where(Flow.id.in_(flow_ids))).all()
        if flow_ids
        else []
    )
    flows_map = {str(f.id): {"name": f.name, "steps": f.steps_json} for f in flows}

    def format_response(r):
        local_time = r.responded_at.replace(tzinfo=ZoneInfo("UTC")).astimezone(tz).isoformat()
        if r.duration_seconds:
            return {
                "type": "timer",
                "time": local_time,
                "duration_seconds": r.duration_seconds,
            }
        return {
            "type": "check-in",
            "time": local_time,
            "flow_id": str(r.flow_id) if r.flow_id else None,
            "steps": r.steps,
            "transcription": r.transcription,
        }

    return {
        "flows": flows_map,
        "responses": [format_response(r) for r in responses],
        "total_count": len(responses),
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

    messages = [{"role": "system", "content": system_prompt}]
    for msg in history:
        messages.append({"role": msg.role, "content": msg.content})

    client = openai.OpenAI(api_key=OPENAI_API_KEY)
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=messages,
        tools=[QUERY_TOOL],
    )

    choice = response.choices[0]

    # Handle tool calls
    if choice.finish_reason == "tool_calls":
        messages.append(choice.message.model_dump())
        for tool_call in choice.message.tool_calls:
            args = json.loads(tool_call.function.arguments)
            result = query_practice_data(
                user.id, session, tz, args.get("start_date"), args.get("end_date")
            )
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": json.dumps(result),
                }
            )

        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            tools=[QUERY_TOOL],
        )
        choice = response.choices[0]

    assistant_content = choice.message.content or ""

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
