from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select, func
from app.db import get_session
from app.models import TimerPreset, TimerPresetCreate, TimerPresetOrderUpdate

router = APIRouter(prefix="/api/timer-presets", tags=["timer_presets"])


@router.get("")
def list_timer_presets(session: Session = Depends(get_session)) -> list[TimerPreset]:
    statement = select(TimerPreset).order_by(TimerPreset.order.asc())
    return session.exec(statement).all()


@router.post("")
def create_timer_preset(data: TimerPresetCreate, session: Session = Depends(get_session)) -> TimerPreset:
    # Get max order and add 1
    max_order = session.exec(select(func.max(TimerPreset.order))).one() or 0
    preset = TimerPreset(
        duration_minutes=data.duration_minutes,
        label=data.label,
        order=max_order + 1
    )
    session.add(preset)
    session.commit()
    session.refresh(preset)
    return preset


@router.put("/order")
def update_preset_orders(updates: list[TimerPresetOrderUpdate], session: Session = Depends(get_session)):
    for update in updates:
        preset = session.get(TimerPreset, update.id)
        if preset:
            preset.order = update.order
            session.add(preset)
    session.commit()
    return {"status": "updated"}


@router.delete("/{preset_id}")
def delete_timer_preset(preset_id: UUID, session: Session = Depends(get_session)):
    preset = session.get(TimerPreset, preset_id)
    if not preset:
        raise HTTPException(status_code=404, detail="Timer preset not found")
    session.delete(preset)
    session.commit()
    return {"status": "deleted"}
