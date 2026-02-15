from typing import Optional
from uuid import UUID
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from app.db import get_session
from app.auth import get_current_user
from app.models import User, Flow

router = APIRouter(prefix="/api/explore", tags=["explore"])


class PublicFlowResponse(BaseModel):
    username: str
    flow_name: str
    description: str
    step_count: int
    steps_json: dict | list


@router.get("/flows", response_model=list[PublicFlowResponse])
def list_public_flows(session: Session = Depends(get_session)):
    rows = session.exec(
        select(User, Flow)
        .join(Flow, User.current_flow_id == Flow.id)
        .where(Flow.visibility == "public")
    ).all()
    return [
        PublicFlowResponse(
            username=user.username,
            flow_name=flow.name,
            description=flow.description,
            step_count=len(flow.steps_json) if isinstance(flow.steps_json, list) else 0,
            steps_json=flow.steps_json,
        )
        for user, flow in rows
    ]


@router.post("/use/{username}")
def use_flow(
    username: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    source_user = session.exec(select(User).where(User.username == username)).first()
    if not source_user or not source_user.current_flow_id:
        raise HTTPException(status_code=404, detail="User or flow not found")

    source_flow = session.get(Flow, source_user.current_flow_id)
    if not source_flow or source_flow.visibility != "public":
        raise HTTPException(status_code=404, detail="Flow not found or not public")

    # Copy the flow for the current user
    new_flow = Flow(
        user_id=user.id,
        name=source_flow.name,
        description=source_flow.description,
        steps_json=source_flow.steps_json,
        source_username=username,
        source_flow_name=source_flow.name,
    )
    session.add(new_flow)
    session.flush()

    user.current_flow_id = new_flow.id
    session.add(user)
    session.commit()

    return {"ok": True, "flow_id": str(new_flow.id)}
