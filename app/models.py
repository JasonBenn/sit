from datetime import datetime
from typing import Optional
from uuid import UUID
import uuid
from sqlmodel import Field, SQLModel, Column
from sqlalchemy import Text
from sqlalchemy.dialects.postgresql import JSONB


class User(SQLModel, table=True):
    __tablename__ = "users"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    username: str = Field(unique=True, index=True)
    password_hash: str
    current_flow_id: Optional[UUID] = Field(default=None, foreign_key="flows.id")
    notification_count: int = 3
    notification_start_hour: int = 9
    notification_end_hour: int = 22
    conversation_starters: Optional[list] = Field(default=None, sa_column=Column(JSONB))
    has_seen_onboarding: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Flow(SQLModel, table=True):
    __tablename__ = "flows"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    name: str
    description: str = ""
    steps_json: dict = Field(sa_column=Column(JSONB))
    source_username: Optional[str] = None
    source_flow_name: Optional[str] = None
    visibility: str = "private"
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Sit(SQLModel, table=True):
    __tablename__ = "sits"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    duration_seconds: float
    started_at: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Checkin(SQLModel, table=True):
    __tablename__ = "checkins"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    flow_id: Optional[UUID] = Field(default=None, foreign_key="flows.id")
    responded_at: datetime
    steps: Optional[list] = Field(default=None, sa_column=Column(JSONB))
    voice_note_s3_url: Optional[str] = None
    voice_note_duration_seconds: Optional[float] = None
    transcription: Optional[str] = Field(default=None, sa_column=Column(Text))
    transcription_status: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class ChatMessage(SQLModel, table=True):
    __tablename__ = "chat_messages"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    role: str  # "user" | "assistant"
    content: str = Field(sa_column=Column(Text))
    created_at: datetime = Field(default_factory=datetime.utcnow)
