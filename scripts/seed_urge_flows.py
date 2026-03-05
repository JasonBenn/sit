"""Idempotent seed script: creates the Urge Inquiry flow for jasoncbenn.

Run after deploying:
  cd /opt/sit && source .venv/bin/activate && python scripts/seed_urge_flows.py
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlmodel import Session, select
from app.db import engine
from app.models import User, Flow

FLOWS = [
    {
        "name": "Urge Inquiry",
        "description": "A quick check-in when you notice a pull toward distraction.",
        "steps_json": [
            {
                "id": 1,
                "title": "What's the pull?",
                "prompt": "You just opened a distracting site. What's the pull right now?",
                "answers": [
                    {"label": "Bored / waiting for something", "destination": 2, "record_voice_note": False},
                    {"label": "Avoiding something hard", "destination": 2, "record_voice_note": False},
                    {"label": "Tired, need a real break", "destination": "submit", "record_voice_note": False},
                    {"label": "Lonely / want connection", "destination": 2, "record_voice_note": False},
                    {"label": "Pure reflex — don't know", "destination": 2, "record_voice_note": False},
                    {"label": "Other", "destination": "submit", "record_voice_note": True},
                ],
            },
            {
                "id": 2,
                "title": "Body check",
                "prompt": "Where do you feel it in your body?",
                "answers": [
                    {"label": "Throat / chest", "destination": "submit", "record_voice_note": False},
                    {"label": "Belly / gut", "destination": "submit", "record_voice_note": False},
                    {"label": "Head / restless mind", "destination": "submit", "record_voice_note": False},
                    {"label": "Nowhere — it passed", "destination": "submit", "record_voice_note": False},
                    {"label": "Other", "destination": "submit", "record_voice_note": True},
                ],
            },
        ],
    },
]


def main():
    with Session(engine) as session:
        user = session.exec(select(User).where(User.username == "jasoncbenn")).first()
        if not user:
            print("ERROR: user 'jasoncbenn' not found")
            sys.exit(1)

        for flow_def in FLOWS:
            existing = session.exec(
                select(Flow)
                .where(Flow.user_id == user.id, Flow.name == flow_def["name"])
            ).first()

            if existing:
                print(f"  already exists: {flow_def['name']!r} ({existing.id})")
                continue

            flow = Flow(
                user_id=user.id,
                name=flow_def["name"],
                description=flow_def["description"],
                steps_json=flow_def["steps_json"],
                visibility="private",
            )
            session.add(flow)
            session.commit()
            session.refresh(flow)
            print(f"  created: {flow.name!r} ({flow.id})")

        print("Done.")


if __name__ == "__main__":
    main()
