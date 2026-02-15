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
        "prompt": "How are you relating to things? With compassion?\n\nAre you seeing them as sacred?\n\nRight conduct is intention & result: do you intend to be of service?",
        "answers": [
            {"label": "Got it", "destination": "submit", "record_voice_note": False},
        ],
    },
    {
        "id": 3,
        "title": "Gate Opening",
        "prompt": "Open through the gate of the ears. No inside and no outside? Can you see through the agent - the illusion that this feeling of center is the cause of your thoughts - or through the idea that the agent's efforts are required?",
        "answers": [
            {"label": "It worked", "destination": 2, "record_voice_note": False},
            {"label": "It didn't work", "destination": 4, "record_voice_note": False},
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
