import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import sentry_sdk

load_dotenv()

# Initialize Sentry before FastAPI app
sentry_dsn = os.getenv("SENTRY_DSN")
if sentry_dsn:
    sentry_sdk.init(
        dsn=sentry_dsn,
        traces_sample_rate=1.0,
        profiles_sample_rate=1.0,
    )

from app.db import init_db
from app.routers import prompt_responses, auth, users, explore, chat

app = FastAPI(title="Sit API", description="Meditation tracking backend")

# CORS - iOS app uses Bearer tokens (not cookies), so credentials aren't needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(prompt_responses.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(explore.router)
app.include_router(chat.router)


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.on_event("startup")
def on_startup():
    init_db()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8005)
