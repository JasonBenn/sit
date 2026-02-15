# Sit App

Meditation prompt flow app for iOS and watchOS.

```yaml
# Claude Code Config
deployCommand: |
  ssh jason "cd /opt/sit && git pull && source .venv/bin/activate && python -m alembic upgrade head && sudo systemctl restart sit"
  if xcrun simctl list devices | grep -q Booted; then
    cd ios && xcodebuild -project Sit.xcodeproj -scheme Sit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5 && xcrun simctl launch --terminate-existing booted com.jasonbenn.sit
  fi
```

## Deployment

The deploy command (run by `/ship`) does:
1. Pull latest changes on the server
2. Run any pending database migrations
3. Restart the sit service
4. If an iOS simulator is booted, rebuild and relaunch the app

## Architecture

- **iOS App** (`ios/Sit/`): iPhone app with PromptFlow UI
- **Watch App** (`ios/SitWatch/`): Apple Watch app with same PromptFlow UI
- **Backend** (`app/`): FastAPI server at sit.jasonbenn.com
- **Database**: PostgreSQL via SQLModel/Alembic

## API Endpoints

- `GET /api/prompt-responses` - List prompt responses
- `POST /api/prompt-responses` - Log a prompt response (with voice note upload/transcription)
- `DELETE /api/prompt-responses/{id}` - Delete a prompt response

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
