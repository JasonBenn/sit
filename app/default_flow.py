DEFAULT_FLOW_NAME = "In the View?"
DEFAULT_FLOW_DESCRIPTION = "A simple check-in to see if you're resting in the View."
DEFAULT_FLOW_STEPS = [
    {
        "id": 1,
        "title": "Check",
        "prompt": "Are you in the View?",
        "answers": [
            {"label": "Yes", "destination": 2, "record_voice_note": False},
            {"label": "No", "destination": 3, "record_voice_note": False},
        ],
    },
    {
        "id": 2,
        "title": "Reflection",
        "prompt": "How are you relating to things right now?\n\nAre you holding things with compassion and openness? Can you sense the sacredness of this moment?",
        "answers": [
            {"label": "Got it", "destination": "submit", "record_voice_note": False},
        ],
    },
    {
        "id": 3,
        "title": "Gate Opening",
        "prompt": "Try this: relax your body, soften your gaze, and let everything just be as it is.\n\nDid it work?",
        "answers": [
            {"label": "It worked", "destination": 2, "record_voice_note": False},
            {"label": "Didn't work", "destination": 4, "record_voice_note": False},
        ],
    },
    {
        "id": 4,
        "title": "Voice Note",
        "prompt": "What's going on?\n\nCan you find the limiting beliefs, or would you like to do parts work?",
        "answers": [
            {"label": "Save", "destination": "submit", "record_voice_note": True},
            {"label": "Skip", "destination": "submit", "record_voice_note": False},
        ],
    },
]
