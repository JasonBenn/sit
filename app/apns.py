"""Apple Push Notification service (APNs) sender.

Requires env vars:
  APNS_KEY_ID      — 10-char key ID from Apple Developer (e.g. AB1234CDEF)
  APNS_TEAM_ID     — 10-char team ID (e.g. JGB9FCMU22)
  APNS_AUTH_KEY    — Full contents of the .p8 file including BEGIN/END lines
  APNS_PRODUCTION  — Set to "true" for production APNs, omit for sandbox
"""
import os
import time
import json
import jwt
import httpx

APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID", "JGB9FCMU22")
APNS_AUTH_KEY = os.getenv("APNS_AUTH_KEY")  # PEM content of .p8 file
APNS_PRODUCTION = os.getenv("APNS_PRODUCTION", "").lower() == "true"

WATCH_BUNDLE_ID = "com.jasonbenn.sit.watchkitapp"

APNS_HOST = (
    "https://api.push.apple.com"
    if APNS_PRODUCTION
    else "https://api.sandbox.push.apple.com"
)


def _make_jwt() -> str:
    """Create a signed JWT for APNs authentication. Valid for 1 hour."""
    payload = {
        "iss": APNS_TEAM_ID,
        "iat": int(time.time()),
    }
    return jwt.encode(
        payload,
        APNS_AUTH_KEY,
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
    return bool(APNS_KEY_ID and APNS_AUTH_KEY)
