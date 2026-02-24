import json
from datetime import datetime
from typing import Optional
from uuid import UUID
import os
import tempfile
import boto3
import openai
from fastapi import APIRouter, Depends, Query, UploadFile, File, Form, HTTPException
from sqlmodel import Session, select
from app.db import get_session
from app.auth import get_current_user
from app.models import Sit, Checkin, User

router = APIRouter(prefix="/api/prompt-responses", tags=["prompt_responses"])

S3_BUCKET = os.getenv("S3_BUCKET", "sit-voice-notes")
AWS_REGION = os.getenv("AWS_REGION", "us-west-2")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")


def get_s3_client():
    return boto3.client("s3", region_name=AWS_REGION)


def transcribe_audio(file_contents: bytes, filename: str) -> str:
    """Transcribe audio using OpenAI Whisper API."""
    client = openai.OpenAI(api_key=OPENAI_API_KEY)

    suffix = "." + filename.split(".")[-1] if "." in filename else ".m4a"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as f:
        f.write(file_contents)
        temp_path = f.name

    try:
        with open(temp_path, "rb") as audio_file:
            transcript = client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                response_format="text"
            )
        return transcript
    finally:
        os.remove(temp_path)


@router.get("")
def list_prompt_responses(
    limit: Optional[int] = Query(default=None),
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[Checkin]:
    statement = (
        select(Checkin)
        .where(Checkin.user_id == user.id)
        .order_by(Checkin.responded_at.desc())
    )
    if limit:
        statement = statement.limit(limit)
    return session.exec(statement).all()


@router.post("")
async def log_prompt_response(
    responded_at: float = Form(...),
    flow_id: Optional[str] = Form(None),
    steps: Optional[str] = Form(None),
    voice_note_duration_seconds: Optional[float] = Form(None),
    duration_seconds: Optional[float] = Form(None),
    voice_note: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    # Route to Sit if duration_seconds is provided (timer/meditation session)
    if duration_seconds is not None:
        started_at = datetime.utcfromtimestamp((responded_at - duration_seconds * 1000) / 1000)
        sit = Sit(
            user_id=user.id,
            duration_seconds=duration_seconds,
            started_at=started_at,
        )
        session.add(sit)
        session.commit()
        session.refresh(sit)
        return sit

    # Otherwise create a Checkin
    s3_url = None
    transcription = None
    transcription_status = None

    if voice_note:
        s3_client = get_s3_client()
        timestamp = int(datetime.utcnow().timestamp() * 1000)
        s3_key = f"voice_notes/{timestamp}_{voice_note.filename}"

        contents = await voice_note.read()
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=contents,
            ContentType=voice_note.content_type or "audio/m4a"
        )
        s3_url = f"s3://{S3_BUCKET}/{s3_key}"

        if OPENAI_API_KEY:
            transcription = transcribe_audio(contents, voice_note.filename)
            transcription_status = "completed"
        else:
            transcription_status = "skipped_no_api_key"

    parsed_steps = json.loads(steps) if steps else None
    parsed_flow_id = UUID(flow_id) if flow_id else None

    checkin = Checkin(
        user_id=user.id,
        flow_id=parsed_flow_id,
        responded_at=datetime.utcfromtimestamp(responded_at / 1000),
        steps=parsed_steps,
        voice_note_s3_url=s3_url,
        voice_note_duration_seconds=voice_note_duration_seconds,
        transcription=transcription,
        transcription_status=transcription_status,
    )

    session.add(checkin)
    session.commit()
    session.refresh(checkin)

    return checkin


@router.delete("/{response_id}")
def delete_prompt_response(
    response_id: UUID,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    # Check sits first
    sit = session.get(Sit, response_id)
    if sit and sit.user_id == user.id:
        session.delete(sit)
        session.commit()
        return {"deleted": True}

    # Then check checkins
    checkin = session.get(Checkin, response_id)
    if not checkin or checkin.user_id != user.id:
        raise HTTPException(status_code=404, detail="Prompt response not found")

    if checkin.voice_note_s3_url:
        s3_client = get_s3_client()
        s3_key = checkin.voice_note_s3_url.replace(f"s3://{S3_BUCKET}/", "")
        s3_client.delete_object(Bucket=S3_BUCKET, Key=s3_key)

    session.delete(checkin)
    session.commit()
    return {"deleted": True}
