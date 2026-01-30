from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from app.db import get_session
from app.models import Belief, BeliefCreate, BeliefUpdate

router = APIRouter(prefix="/api/beliefs", tags=["beliefs"])


@router.get("")
def list_beliefs(session: Session = Depends(get_session)) -> list[Belief]:
    statement = select(Belief).order_by(Belief.created_at.desc())
    return session.exec(statement).all()


@router.post("")
def create_belief(data: BeliefCreate, session: Session = Depends(get_session)) -> Belief:
    belief = Belief(text=data.text)
    session.add(belief)
    session.commit()
    session.refresh(belief)
    return belief


@router.put("/{belief_id}")
def update_belief(belief_id: UUID, data: BeliefUpdate, session: Session = Depends(get_session)) -> Belief:
    belief = session.get(Belief, belief_id)
    if not belief:
        raise HTTPException(status_code=404, detail="Belief not found")
    belief.text = data.text
    belief.updated_at = datetime.utcnow()
    session.add(belief)
    session.commit()
    session.refresh(belief)
    return belief


@router.delete("/{belief_id}")
def delete_belief(belief_id: UUID, session: Session = Depends(get_session)):
    belief = session.get(Belief, belief_id)
    if not belief:
        raise HTTPException(status_code=404, detail="Belief not found")
    session.delete(belief)
    session.commit()
    return {"status": "deleted"}
