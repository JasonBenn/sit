from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, select
from app.db import get_session
from app.models import MeditationSession, MeditationSessionCreate

router = APIRouter(prefix="/api/meditation-sessions", tags=["meditation_sessions"])


@router.get("")
def list_meditation_sessions(
    limit: Optional[int] = Query(default=None),
    session: Session = Depends(get_session)
) -> list[MeditationSession]:
    statement = select(MeditationSession).order_by(MeditationSession.completed_at.desc())
    if limit:
        statement = statement.limit(limit)
    return session.exec(statement).all()


@router.post("")
def log_meditation_session(data: MeditationSessionCreate, session: Session = Depends(get_session)) -> MeditationSession:
    # Convert ms timestamps to datetime
    meditation = MeditationSession(
        duration_minutes=data.duration_minutes,
        started_at=datetime.fromtimestamp(data.started_at / 1000),
        completed_at=datetime.fromtimestamp(data.completed_at / 1000),
        has_inner_timers=data.has_inner_timers
    )
    session.add(meditation)
    session.commit()
    session.refresh(meditation)
    return meditation
