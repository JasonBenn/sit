"""Endpoints for registering device tokens and triggering watch check-ins.

POST /api/devices/register  — store a Watch APNs device token (user auth)
POST /api/trigger           — send a push to the user's Watch (secret auth)
"""
import json
import os
from pydantic import BaseModel
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlmodel import Session, select

from app.db import get_session
from app.auth import get_current_user
from app.models import User, Flow, DeviceToken
from app import apns

router = APIRouter(tags=["triggers"])

TRIGGER_SECRET = os.getenv("TRIGGER_SECRET")


# ---------------------------------------------------------------------------
# Device token registration (called by Watch app after APNs registration)
# ---------------------------------------------------------------------------

class RegisterDeviceRequest(BaseModel):
    token: str
    platform: str = "watchos"


@router.post("/api/devices/register")
def register_device(
    body: RegisterDeviceRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    # Upsert: update existing token row if already stored, else insert
    existing = session.exec(
        select(DeviceToken).where(DeviceToken.token == body.token)
    ).first()

    if existing:
        existing.user_id = user.id
        existing.platform = body.platform
        session.add(existing)
    else:
        device = DeviceToken(user_id=user.id, token=body.token, platform=body.platform)
        session.add(device)

    session.commit()
    return {"ok": True}


# ---------------------------------------------------------------------------
# Trigger endpoint (called by Mac daemon, authenticated by shared secret)
# ---------------------------------------------------------------------------

class TriggerRequest(BaseModel):
    username: str = "jasoncbenn"
    flow_name: str
    schedule_type: str = "webhook"


@router.post("/api/trigger")
async def trigger_checkin(
    body: TriggerRequest,
    x_trigger_secret: str = Header(default=None, alias="X-Trigger-Secret"),
    session: Session = Depends(get_session),
):
    if not TRIGGER_SECRET or x_trigger_secret != TRIGGER_SECRET:
        raise HTTPException(status_code=401, detail="Invalid trigger secret")

    # Look up user
    user = session.exec(select(User).where(User.username == body.username)).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User {body.username!r} not found")

    # Look up the named flow owned by this user
    flow = session.exec(
        select(Flow)
        .where(Flow.user_id == user.id, Flow.name == body.flow_name)
        .order_by(Flow.created_at.desc())
    ).first()
    if not flow:
        raise HTTPException(status_code=404, detail=f"Flow {body.flow_name!r} not found for user")

    # Get all Watch device tokens for this user
    tokens = session.exec(
        select(DeviceToken)
        .where(DeviceToken.user_id == user.id, DeviceToken.platform == "watchos")
    ).all()
    if not tokens:
        raise HTTPException(status_code=404, detail="No Watch device tokens registered for user")

    if not apns.is_configured():
        raise HTTPException(status_code=503, detail="APNs not configured (missing env vars)")

    # Embed the full flow definition in the push payload so the Watch can
    # run it without a network round-trip.
    flow_payload = {
        "flow_id": str(flow.id),
        "flow_name": flow.name,
        "steps_json": json.dumps(flow.steps_json),
        "schedule_type": body.schedule_type,
    }

    errors = []
    for device in tokens:
        try:
            await apns.send_push(
                device_token=device.token,
                title="Check In",
                body=flow.steps_json[0]["prompt"] if flow.steps_json else "Time to check in.",
                extra=flow_payload,
            )
        except Exception as e:
            errors.append({"token": device.token[:8] + "...", "error": str(e)})

    if errors and len(errors) == len(tokens):
        raise HTTPException(status_code=502, detail=f"All APNs sends failed: {errors}")

    return {"ok": True, "sent": len(tokens) - len(errors), "errors": errors}
