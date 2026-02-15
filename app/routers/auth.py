import re
from uuid import UUID
from pydantic import BaseModel, field_validator
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from app.db import get_session
from app.auth import hash_password, verify_password, create_token, get_current_user
from app.models import User, Flow, PromptResponse, ChatMessage
from app.default_flow import DEFAULT_FLOW_NAME, DEFAULT_FLOW_DESCRIPTION, DEFAULT_FLOW_STEPS

router = APIRouter(prefix="/api/auth", tags=["auth"])


class SignupRequest(BaseModel):
    username: str
    password: str

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        if not 3 <= len(v) <= 30:
            raise ValueError("Username must be 3-30 characters")
        if not re.match(r"^[a-zA-Z0-9_]+$", v):
            raise ValueError("Username must be alphanumeric + underscores only")
        return v.lower()

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


class LoginRequest(BaseModel):
    username: str
    password: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("New password must be at least 6 characters")
        return v


class UserResponse(BaseModel):
    id: UUID
    username: str
    has_seen_onboarding: bool


class AuthResponse(BaseModel):
    token: str
    user: UserResponse


@router.post("/signup", response_model=AuthResponse)
def signup(body: SignupRequest, session: Session = Depends(get_session)):
    existing = session.exec(select(User).where(User.username == body.username)).first()
    if existing:
        raise HTTPException(status_code=409, detail="Username already taken")

    user = User(
        username=body.username,
        password_hash=hash_password(body.password),
    )
    session.add(user)
    session.flush()

    # Create default flow
    flow = Flow(
        user_id=user.id,
        name=DEFAULT_FLOW_NAME,
        description=DEFAULT_FLOW_DESCRIPTION,
        steps_json=DEFAULT_FLOW_STEPS,
    )
    session.add(flow)
    session.flush()

    user.current_flow_id = flow.id
    session.commit()
    session.refresh(user)

    token = create_token(user.id)
    return AuthResponse(
        token=token,
        user=UserResponse(id=user.id, username=user.username, has_seen_onboarding=user.has_seen_onboarding),
    )


@router.post("/login", response_model=AuthResponse)
def login(body: LoginRequest, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.username == body.username.lower())).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid username or password")

    token = create_token(user.id)
    return AuthResponse(
        token=token,
        user=UserResponse(id=user.id, username=user.username, has_seen_onboarding=user.has_seen_onboarding),
    )


@router.post("/change-password")
def change_password(
    body: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    user.password_hash = hash_password(body.new_password)
    session.add(user)
    session.commit()
    return {"ok": True}


@router.delete("/account")
def delete_account(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    # Delete all user data
    for msg in session.exec(select(ChatMessage).where(ChatMessage.user_id == user.id)):
        session.delete(msg)
    for resp in session.exec(select(PromptResponse).where(PromptResponse.user_id == user.id)):
        session.delete(resp)
    for flow in session.exec(select(Flow).where(Flow.user_id == user.id)):
        session.delete(flow)
    session.delete(user)
    session.commit()
    return {"ok": True}
