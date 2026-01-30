from datetime import datetime
from typing import Optional
from uuid import UUID
import uuid
from sqlmodel import Field, SQLModel, Column
from sqlalchemy import Text
from sqlalchemy.dialects.postgresql import JSONB


class Belief(SQLModel, table=True):
    __tablename__ = "beliefs"
    
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    text: str = Field(sa_column=Column(Text, nullable=False))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class TimerPreset(SQLModel, table=True):
    __tablename__ = "timer_presets"
    
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    duration_minutes: int
    label: Optional[str] = None
    order: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)


class PromptSettings(SQLModel, table=True):
    __tablename__ = "prompt_settings"
    
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    notification_times: list = Field(default=[], sa_column=Column(JSONB))
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class MeditationSession(SQLModel, table=True):
    __tablename__ = "meditation_sessions"
    
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    duration_minutes: int
    started_at: datetime
    completed_at: datetime
    has_inner_timers: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)


class PromptResponse(SQLModel, table=True):
    __tablename__ = "prompt_responses"
    
    id: UUID = Field(primary_key=True, default_factory=uuid.uuid4)
    responded_at: datetime
    initial_answer: str  # 'in_view' | 'not_in_view'
    gate_exercise_result: Optional[str] = None  # 'worked' | 'didnt_work' | None
    final_state: str  # 'reflection_complete' | 'voice_note_recorded'
    voice_note_s3_url: Optional[str] = None
    voice_note_duration_seconds: Optional[float] = None
    transcription: Optional[str] = Field(default=None, sa_column=Column(Text))
    transcription_status: Optional[str] = None  # 'pending' | 'processing' | 'completed' | 'failed'
    created_at: datetime = Field(default_factory=datetime.utcnow)


# Request/Response schemas for API
class BeliefCreate(SQLModel):
    text: str


class BeliefUpdate(SQLModel):
    text: str


class TimerPresetCreate(SQLModel):
    duration_minutes: int
    label: Optional[str] = None


class TimerPresetOrderUpdate(SQLModel):
    id: UUID
    order: int


class PromptSettingsUpdate(SQLModel):
    notification_times: list


class MeditationSessionCreate(SQLModel):
    duration_minutes: int
    started_at: float  # ms timestamp
    completed_at: float  # ms timestamp
    has_inner_timers: bool = False


class PromptResponseCreate(SQLModel):
    responded_at: float  # ms timestamp
    initial_answer: str
    gate_exercise_result: Optional[str] = None
    final_state: str
    voice_note_duration_seconds: Optional[float] = None
