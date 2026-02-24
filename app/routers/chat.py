import json
import os
from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel
import openai
from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from app.db import get_session
from app.auth import get_current_user
from app.models import User, Flow, PromptResponse, ChatMessage

router = APIRouter(prefix="/api/chat", tags=["chat"])

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

SYSTEM_PROMPT = """You are a meditation practice assistant for the Sit app. The user tracks their meditation practice through check-in flows. You can query their practice data to help them understand patterns and progress. Be warm, insightful, and concise."""

QUERY_TOOL = {
    "type": "function",
    "function": {
        "name": "query_practice_data",
        "description": "Query the user's meditation practice data. Returns check-in responses with flow definitions.",
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


class ChatMessageResponse(BaseModel):
    id: UUID
    role: str
    content: str
    created_at: datetime


def query_practice_data(user_id: UUID, session: Session, start_date: Optional[str] = None, end_date: Optional[str] = None) -> dict:
    stmt = select(PromptResponse).where(PromptResponse.user_id == user_id).order_by(PromptResponse.responded_at.desc())
    if start_date:
        stmt = stmt.where(PromptResponse.responded_at >= datetime.fromisoformat(start_date))
    if end_date:
        stmt = stmt.where(PromptResponse.responded_at <= datetime.fromisoformat(end_date))

    responses = session.exec(stmt).all()

    # Collect unique flow IDs and batch-fetch definitions
    flow_ids = {r.flow_id for r in responses if r.flow_id}
    flows = session.exec(select(Flow).where(Flow.id.in_(flow_ids))).all() if flow_ids else []
    flows_map = {str(f.id): {"name": f.name, "steps": f.steps_json} for f in flows}

    return {
        "flows": flows_map,
        "responses": [
            {
                "flow_id": str(r.flow_id) if r.flow_id else None,
                "steps": r.steps,
                "responded_at": r.responded_at.isoformat(),
                "transcription": r.transcription,
            }
            for r in responses
        ],
        "total_count": len(responses),
    }


@router.post("")
def chat(
    body: ChatRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
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

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
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
            result = query_practice_data(user.id, session, args.get("start_date"), args.get("end_date"))
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": json.dumps(result),
            })

        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            tools=[QUERY_TOOL],
        )
        choice = response.choices[0]

    assistant_content = choice.message.content or ""

    # Save assistant message
    assistant_msg = ChatMessage(user_id=user.id, role="assistant", content=assistant_content)
    session.add(assistant_msg)
    session.commit()
    session.refresh(assistant_msg)

    return {"id": str(assistant_msg.id), "role": assistant_msg.role, "content": assistant_msg.content, "created_at": assistant_msg.created_at.isoformat()}


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
