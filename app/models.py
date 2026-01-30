from datetime import datetime
from typing import Optional
from uuid import UUID
import uuid
from sqlmodel import Field, SQLModel, Column
from sqlalchemy import Text


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
