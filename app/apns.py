"""Apple Push Notification service (APNs) sender.

Requires env vars:
  APNS_KEY_ID       — 10-char key ID from Apple Developer (e.g. G2X3SPLGVU)
  APNS_TEAM_ID      — 10-char team ID (e.g. JGB9FCMU22)
  APNS_AUTH_KEY_PATH — Path to the .p8 file (e.g. /opt/sit/AuthKey_G2X3SPLGVU.p8)
  APNS_PRODUCTION   — Set to "true" for production APNs, omit for sandbox/development
"""
import os
import time
import json
import jwt
import httpx

APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID", "JGB9FCMU22")
APNS_AUTH_KEY_PATH = os.getenv("APNS_AUTH_KEY_PATH")
APNS_PRODUCTION = os.getenv("APNS_PRODUCTION", "").lower() == "true"

WATCH_BUNDLE_ID = "com.jasonbenn.sit.watchkitapp"

APNS_HOST = (
    "https://api.push.apple.com"
    if APNS_PRODUCTION
    else "https://api.sandbox.push.apple.com"
)


def _load_auth_key() -> str:
    if APNS_AUTH_KEY_PATH:
        with open(APNS_AUTH_KEY_PATH) as f:
            return f.read()
    raise RuntimeError("APNS_AUTH_KEY_PATH not set")


def _make_jwt() -> str:
    """Create a signed JWT for APNs authentication. Valid for 1 hour."""
    payload = {
        "iss": APNS_TEAM_ID,
        "iat": int(time.time()),
    }
    return jwt.encode(
        payload,
        _load_auth_key(),
        algorithm="ES256",
        headers={"kid": APNS_KEY_ID},
    )


async def send_push(device_token: str, title: str, body: str, extra: dict = None) -> None:
    """Send an APNs push notification to a Watch device token.

    extra: additional key/value pairs merged into the payload (alongside 'aps').
    Raises httpx.HTTPStatusError on APNs error responses.
    """
    payload = {
        "aps": {
            "alert": {"title": title, "body": body},
            "sound": "default",
        }
    }
    if extra:
        payload.update(extra)

    token = _make_jwt()
    url = f"{APNS_HOST}/3/device/{device_token}"
    headers = {
        "authorization": f"bearer {token}",
        "apns-topic": WATCH_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
    }

    async with httpx.AsyncClient(http2=True) as client:
        response = await client.post(url, content=json.dumps(payload), headers=headers)
        response.raise_for_status()


def is_configured() -> bool:
    return bool(APNS_KEY_ID and APNS_AUTH_KEY_PATH)
