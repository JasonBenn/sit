"""
Transcription worker using PGBoss job queue and OpenAI Whisper API.
Run with: python -m app.workers.transcription
"""
import os
import time
import json
import tempfile
import boto3
from datetime import datetime
from sqlalchemy import text
from sqlmodel import Session
import openai

from app.db import engine

S3_BUCKET = os.getenv("S3_BUCKET", "sit-voice-notes")
AWS_REGION = os.getenv("AWS_REGION", "us-west-2")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

def get_s3_client():
    return boto3.client("s3", region_name=AWS_REGION)


def fetch_job():
    """Fetch a pending transcription job from pgboss queue."""
    with Session(engine) as session:
        result = session.execute(text("""
            UPDATE pgboss.job
            SET state = 'active', started_on = NOW()
            WHERE id = (
                SELECT id FROM pgboss.job
                WHERE name = 'transcribe_voice_note'
                AND state = 'created'
                ORDER BY created_on ASC
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            )
            RETURNING id, data
        """))
        row = result.fetchone()
        session.commit()
        return row


def complete_job(job_id: str, error: str = None):
    """Mark a job as completed or failed."""
    with Session(engine) as session:
        if error:
            session.execute(text("""
                UPDATE pgboss.job
                SET state = 'failed', completed_on = NOW(), error = :error
                WHERE id = :job_id
            """), {"job_id": job_id, "error": error})
        else:
            session.execute(text("""
                UPDATE pgboss.job
                SET state = 'completed', completed_on = NOW()
                WHERE id = :job_id
            """), {"job_id": job_id})
        session.commit()


def download_from_s3(s3_url: str) -> str:
    """Download file from S3 to temp file, return path."""
    s3_client = get_s3_client()
    
    # Parse s3://bucket/key format
    parts = s3_url.replace("s3://", "").split("/", 1)
    bucket = parts[0]
    key = parts[1]
    
    # Download to temp file
    suffix = "." + key.split(".")[-1] if "." in key else ".m4a"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as f:
        s3_client.download_fileobj(bucket, key, f)
        return f.name


def transcribe_audio(file_path: str) -> str:
    """Transcribe audio file using OpenAI Whisper API."""
    client = openai.OpenAI(api_key=OPENAI_API_KEY)
    
    with open(file_path, "rb") as audio_file:
        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file,
            response_format="text"
        )
    
    return transcript


def update_prompt_response(response_id: str, transcription: str, status: str):
    """Update the prompt_responses table with transcription result."""
    with Session(engine) as session:
        session.execute(text("""
            UPDATE prompt_responses
            SET transcription = :transcription,
                transcription_status = :status
            WHERE id = :response_id
        """), {
            "response_id": response_id,
            "transcription": transcription,
            "status": status
        })
        session.commit()


def process_job(job_id: str, data: dict):
    """Process a single transcription job."""
    response_id = data.get("response_id")
    if not response_id:
        complete_job(job_id, "Missing response_id in job data")
        return
    
    print(f"Processing job {job_id} for response {response_id}")
    
    # Update status to processing
    update_prompt_response(response_id, None, "processing")
    
    try:
        # Get the S3 URL from prompt_responses
        with Session(engine) as session:
            result = session.execute(text("""
                SELECT voice_note_s3_url FROM prompt_responses WHERE id = :id
            """), {"id": response_id})
            row = result.fetchone()
            
            if not row or not row[0]:
                raise Exception("No voice note URL found")
            
            s3_url = row[0]
        
        # Download from S3
        local_path = download_from_s3(s3_url)
        
        try:
            # Transcribe
            transcription = transcribe_audio(local_path)
            
            # Update database
            update_prompt_response(response_id, transcription, "completed")
            complete_job(job_id)
            
            print(f"Successfully transcribed: {transcription[:100]}...")
        finally:
            # Clean up temp file
            if os.path.exists(local_path):
                os.remove(local_path)
                
    except Exception as e:
        error_msg = str(e)
        print(f"Error processing job {job_id}: {error_msg}")
        update_prompt_response(response_id, None, "failed")
        complete_job(job_id, error_msg)


def run_worker():
    """Main worker loop."""
    print("Starting transcription worker...")
    print(f"S3 Bucket: {S3_BUCKET}")
    print(f"OpenAI API Key configured: {'Yes' if OPENAI_API_KEY else 'No'}")
    
    while True:
        try:
            job = fetch_job()
            
            if job:
                job_id, data_str = job
                # Parse JSON data
                try:
                    data = json.loads(data_str) if isinstance(data_str, str) else data_str
                except:
                    data = {}
                
                process_job(str(job_id), data)
            else:
                # No jobs, wait before polling again
                time.sleep(5)
                
        except KeyboardInterrupt:
            print("Worker stopped")
            break
        except Exception as e:
            print(f"Worker error: {e}")
            time.sleep(10)


if __name__ == "__main__":
    run_worker()
