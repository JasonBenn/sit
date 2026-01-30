from datetime import datetime
from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from app.db import get_session
from app.models import PromptSettings, PromptSettingsUpdate

router = APIRouter(prefix="/api/prompt-settings", tags=["prompt_settings"])


@router.get("")
def get_prompt_settings(session: Session = Depends(get_session)) -> PromptSettings | None:
    statement = select(PromptSettings)
    return session.exec(statement).first()


@router.put("")
def update_prompt_settings(data: PromptSettingsUpdate, session: Session = Depends(get_session)) -> PromptSettings:
    statement = select(PromptSettings)
    settings = session.exec(statement).first()
    
    if settings:
        settings.notification_times = data.notification_times
        settings.updated_at = datetime.utcnow()
    else:
        settings = PromptSettings(notification_times=data.notification_times)
    
    session.add(settings)
    session.commit()
    session.refresh(settings)
    return settings
