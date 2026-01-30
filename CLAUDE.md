# Sit App

Meditation prompt flow app for iOS and watchOS.

## Deployment

When pushing changes, run the deploy script to update the backend:

```bash
ssh jason "cd /opt/sit && git pull && source .venv/bin/activate && python -m alembic upgrade head && sudo systemctl restart sit"
```

This will:
1. Pull latest changes on the server
2. Run any pending database migrations
3. Restart the sit service

## Architecture

- **iOS App** (`ios/Sit/`): iPhone app with PromptFlow UI
- **Watch App** (`ios/SitWatch/`): Apple Watch app with same PromptFlow UI
- **Backend** (`app/`): FastAPI server at sit.jasonbenn.com
- **Database**: PostgreSQL via SQLModel/Alembic

## API Endpoints

- `POST /api/prompt-responses` - Log a prompt response
- `GET /api/prompt-responses` - List prompt responses

## Error Handling

**Let it crash.** Don't wrap code in try/except - just let exceptions propagate. Sentry's middleware catches all unhandled exceptions automatically.

Bad:
```python
try:
    upload_to_s3(file)
except Exception as e:
    print(f"Upload failed: {e}")  # Silent failure
```

Good:
```python
upload_to_s3(file)  # If it fails, Sentry catches it, caller gets 500
