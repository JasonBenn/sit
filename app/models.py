from datetime import datetime, timezone
from typing import Optional
from uuid import UUID
import uuid
import sqlalchemy as sa
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
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))


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
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))


class Sit(SQLModel, table=True):
    __tablename__ = "sits"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    duration_seconds: float
    started_at: datetime = Field(sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))
    timezone: Optional[str] = Field(default=None, sa_column=sa.Column(sa.String, nullable=True))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))


class Checkin(SQLModel, table=True):
    __tablename__ = "checkins"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    flow_id: Optional[UUID] = Field(default=None, foreign_key="flows.id")
    responded_at: datetime = Field(sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))
    steps: Optional[list] = Field(default=None, sa_column=Column(JSONB))
    voice_note_s3_url: Optional[str] = None
    voice_note_duration_seconds: Optional[float] = None
    transcription: Optional[str] = Field(default=None, sa_column=Column(Text))
    transcription_status: Optional[str] = None
    schedule_type: Optional[str] = None
    timezone: Optional[str] = Field(default=None, sa_column=sa.Column(sa.String, nullable=True))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))


class DeviceToken(SQLModel, table=True):
    __tablename__ = "device_tokens"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    token: str = Field(unique=True)
    platform: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))


class ChatMessage(SQLModel, table=True):
    __tablename__ = "chat_messages"
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    user_id: UUID = Field(foreign_key="users.id")
    role: str
    content: str = Field(sa_column=Column(Text))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=sa.Column(sa.DateTime(timezone=True), nullable=False))
