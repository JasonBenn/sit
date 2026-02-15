from typing import Optional
from uuid import UUID
from pydantic import BaseModel
from fastapi import APIRouter, Depends
from sqlmodel import Session
from app.db import get_session
from app.auth import get_current_user
from app.models import User, Flow

router = APIRouter(prefix="/api/me", tags=["users"])


class FlowResponse(BaseModel):
    id: UUID
    name: str
    description: str
    steps_json: dict | list
    source_username: Optional[str]
    source_flow_name: Optional[str]
    visibility: str


class UserProfileResponse(BaseModel):
    id: UUID
    username: str
    notification_count: int
    notification_start_hour: int
    notification_end_hour: int
    conversation_starters: Optional[list]
    has_seen_onboarding: bool
    current_flow: Optional[FlowResponse]


class UpdateFlowRequest(BaseModel):
    name: str
    description: str = ""
    steps_json: dict | list
    visibility: str = "private"
    source_username: Optional[str] = None
    source_flow_name: Optional[str] = None


class UpdateNotificationsRequest(BaseModel):
    count: int
    start_hour: int
    end_hour: int


class UpdateConversationStartersRequest(BaseModel):
    starters: list[str]


@router.get("", response_model=UserProfileResponse)
def get_profile(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    current_flow = None
    if user.current_flow_id:
        flow = session.get(Flow, user.current_flow_id)
        if flow:
            current_flow = FlowResponse(
                id=flow.id,
                name=flow.name,
                description=flow.description,
                steps_json=flow.steps_json,
                source_username=flow.source_username,
                source_flow_name=flow.source_flow_name,
                visibility=flow.visibility,
            )

    return UserProfileResponse(
        id=user.id,
        username=user.username,
        notification_count=user.notification_count,
        notification_start_hour=user.notification_start_hour,
        notification_end_hour=user.notification_end_hour,
        conversation_starters=user.conversation_starters,
        has_seen_onboarding=user.has_seen_onboarding,
        current_flow=current_flow,
    )


@router.put("/flow", response_model=FlowResponse)
def update_flow(
    body: UpdateFlowRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    # If flow has source attribution and was modified, auto-flip to private
    visibility = body.visibility
    if body.source_username:
        # Check if the source flow still matches
        from sqlmodel import select
        source_user = session.exec(select(User).where(User.username == body.source_username)).first()
        if source_user and source_user.current_flow_id:
            source_flow = session.get(Flow, source_user.current_flow_id)
            if source_flow and source_flow.steps_json != body.steps_json:
                visibility = "private"

    flow = Flow(
        user_id=user.id,
        name=body.name,
        description=body.description,
        steps_json=body.steps_json,
        source_username=body.source_username,
        source_flow_name=body.source_flow_name,
        visibility=visibility,
    )
    session.add(flow)
    session.flush()

    user.current_flow_id = flow.id
    session.add(user)
    session.commit()
    session.refresh(flow)

    return FlowResponse(
        id=flow.id,
        name=flow.name,
        description=flow.description,
        steps_json=flow.steps_json,
        source_username=flow.source_username,
        source_flow_name=flow.source_flow_name,
        visibility=flow.visibility,
    )


@router.put("/notifications")
def update_notifications(
    body: UpdateNotificationsRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    user.notification_count = body.count
    user.notification_start_hour = body.start_hour
    user.notification_end_hour = body.end_hour
    session.add(user)
    session.commit()
    return {"ok": True}


@router.put("/conversation-starters")
def update_conversation_starters(
    body: UpdateConversationStartersRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    user.conversation_starters = body.starters
    session.add(user)
    session.commit()
    return {"ok": True}


@router.put("/onboarding-seen")
def mark_onboarding_seen(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    user.has_seen_onboarding = True
    session.add(user)
    session.commit()
    return {"ok": True}
