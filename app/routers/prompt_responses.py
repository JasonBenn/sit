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
from app.models import PromptResponse

router = APIRouter(prefix="/api/prompt-responses", tags=["prompt_responses"])

S3_BUCKET = os.getenv("S3_BUCKET", "sit-voice-notes")
AWS_REGION = os.getenv("AWS_REGION", "us-west-2")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")


def get_s3_client():
    return boto3.client("s3", region_name=AWS_REGION)


def transcribe_audio(file_contents: bytes, filename: str) -> str:
    """Transcribe audio using OpenAI Whisper API."""
    client = openai.OpenAI(api_key=OPENAI_API_KEY)
    
    # Write to temp file (OpenAI API needs a file)
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
    session: Session = Depends(get_session)
) -> list[PromptResponse]:
    statement = select(PromptResponse).order_by(PromptResponse.responded_at.desc())
    if limit:
        statement = statement.limit(limit)
    return session.exec(statement).all()


@router.post("")
async def log_prompt_response(
    responded_at: float = Form(...),
    initial_answer: str = Form(...),
    final_state: str = Form(...),
    gate_exercise_result: Optional[str] = Form(None),
    voice_note_duration_seconds: Optional[float] = Form(None),
    voice_note: Optional[UploadFile] = File(None),
    session: Session = Depends(get_session)
) -> PromptResponse:
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
        
        # Transcribe synchronously (voice notes are short)
        if OPENAI_API_KEY:
            transcription = transcribe_audio(contents, voice_note.filename)
            transcription_status = "completed"
        else:
            transcription_status = "skipped_no_api_key"

    response = PromptResponse(
        responded_at=datetime.fromtimestamp(responded_at / 1000),
        initial_answer=initial_answer,
        gate_exercise_result=gate_exercise_result,
        final_state=final_state,
        voice_note_s3_url=s3_url,
        voice_note_duration_seconds=voice_note_duration_seconds,
        transcription=transcription,
        transcription_status=transcription_status
    )

    session.add(response)
    session.commit()
    session.refresh(response)

    return response


@router.delete("/{response_id}")
def delete_prompt_response(
    response_id: UUID,
    session: Session = Depends(get_session)
) -> dict:
    response = session.get(PromptResponse, response_id)
    if not response:
        raise HTTPException(status_code=404, detail="Prompt response not found")

    # Delete S3 object if exists
    if response.voice_note_s3_url:
        s3_client = get_s3_client()
        # Parse s3://bucket/key format
        s3_key = response.voice_note_s3_url.replace(f"s3://{S3_BUCKET}/", "")
        s3_client.delete_object(Bucket=S3_BUCKET, Key=s3_key)

    session.delete(response)
    session.commit()
    return {"deleted": True}
