#!/usr/bin/env python3
"""Exercise the morning flow without waiting on NotebookLM.

  --canned   seed a fixture session, no model calls, instant. For UI work:
             start the app against the same scratch DB and look at it.
  --live     drive the real endpoints with the notebook stubbed. For flow work:
             greeting -> check-in -> async Rigdzin -> resumed turn -> routine.
  --second-round
             seed a morning that already sat once, then ask for another round.
             The model must call propose_program again, not write the card as
             text (the 2026-09-18 regression: replayed tool markers read as its
             own prose, so it imitated them). --runs N repeats it.

Both run against a scratch database and a throwaway wake-up log, so neither can
touch the real morning sessions or ~/notes. The DB name must contain "eval".

  createdb sit_eval
  scripts/eval_morning.py --canned
  DATABASE_URL=postgresql:///sit_eval uvicorn app.server:app --port 8010
  open http://127.0.0.1:8010/sit
"""
import argparse
import json
import os
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone as tz

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, REPO)

EVAL_USER = "eval"
DEFAULT_DB = "postgresql:///sit_eval"


def prepare_env(args) -> str:
    """Point every external dependency at something disposable. Must run before
    app modules are imported — they read these at import time."""
    db = os.environ.get("DATABASE_URL", DEFAULT_DB)
    if "eval" not in db and not args.force:
        sys.exit(f"refusing to run against {db!r} — the DB name must contain 'eval' "
                 f"(createdb sit_eval), or pass --force")
    os.environ["DATABASE_URL"] = db

    os.environ["MORNING_USERNAME"] = EVAL_USER
    os.environ["NOTEBOOKLM_BIN"] = os.path.join(REPO, "scripts", "stub_notebooklm.py")
    if args.notebook_delay:
        os.environ["EVAL_NOTEBOOK_DELAY"] = str(args.notebook_delay)
    if args.notebook_fail:
        os.environ["EVAL_NOTEBOOK_FAIL"] = "1"

    # A stable path, so the eval and the server it is inspected through agree.
    log = os.environ.get(
        "WAKE_UP_LOG", os.path.join(tempfile.gettempdir(), "sit-eval-wake-up.md"))
    os.environ["WAKE_UP_LOG"] = log
    if not os.path.exists(log) or not os.path.getsize(log):
        # journal.write_entry inserts *after* the description line; give it one,
        # plus a couple of entries so the log pane renders like the real thing.
        with open(log, "w") as f:
            f.write(EVAL_LOG_SEED)
    return db


EVAL_LOG_SEED = """*Eval wake-up log.*
### [[2026-09-16]] Fear in the gut, named — sit unconfirmed
- Woke up avoidant and scared; the fear was **in the gut**, not the throat.
- Carry forward: name where it lands before reaching for a frame.
### [[2026-09-09]] 30-min sit: gather, then release
- Two-phase intention: gather concentration, then take the foot off the gas.
- **Centerlessness was intuitive** for stretches; got distracted by good ideas.
"""


def setup_db():
    """Empty scratch DB -> schema + seeded components + the eval user."""
    from sqlmodel import Session, select
    from app.db import engine, init_db
    from app import library
    from app.models import User

    init_db()
    with Session(engine) as session:
        library.ensure_seeds(session)
        user = session.exec(select(User).where(User.username == EVAL_USER)).first()
        if user is None:
            user = User(username=EVAL_USER, password_hash="eval-only")
            session.add(user)
        session.commit()
        session.refresh(user)
        return user.id


def reset_sessions():
    """Drop previous eval conversations so each run starts clean."""
    from sqlmodel import Session, select, delete
    from app.db import engine
    from app.models import MorningMessage, MorningSession, User

    with Session(engine) as session:
        user = session.exec(select(User).where(User.username == EVAL_USER)).one()
        ids = session.exec(
            select(MorningSession.id).where(MorningSession.user_id == user.id)
        ).all()
        if ids:
            session.exec(delete(MorningMessage).where(MorningMessage.session_id.in_(ids)))
            session.exec(delete(MorningSession).where(MorningSession.id.in_(ids)))
        session.commit()


# ---------------------------------------------------------------- canned mode

def seed_canned(user_id, with_pending: bool):
    """A fixture morning: the shapes the UI has to render, with no model in the
    loop — greeting, check-in, an answered Rigdzin card, a proposed routine."""
    from sqlmodel import Session
    from app.db import engine
    from app import library
    from app.models import MorningMessage, MorningSession

    from scripts.stub_notebooklm import ANSWER

    with Session(engine) as session:
        morning = MorningSession(user_id=user_id)
        session.add(morning)
        session.commit()
        session.refresh(morning)

        t0 = datetime.now(tz.utc) - timedelta(minutes=10)

        def add(role, content, *, tool_label=None, data=None, offset=0):
            session.add(MorningMessage(
                session_id=morning.id, role=role, content=content,
                tool_label=tool_label, data=data,
                created_at=t0 + timedelta(seconds=offset),
            ))

        question = ("When the relative self is the object of contempt, how do the "
                    "teachings recommend holding the hurt with compassion rather "
                    "than bypassing it into emptiness?")

        add("assistant",
            "Morning. Last week's sit left the body-mapping question open — where "
            "stress lands first. What's alive right now?", offset=0)
        add("user",
            "Relationship conflict. My relative self is the object of contempt and "
            "I want to hold it with compassion instead of jumping to emptiness.",
            offset=30)
        add("assistant",
            "That's worth asking the tradition about directly. Let me check with "
            "Rigdzin — back in a moment.", offset=45)
        add("tool", question, tool_label="Asked Rigdzin notebook",
            data={"question": question, "answer": ANSWER, "status": "done"}, offset=60)
        add("assistant",
            "Rigdzin's steer: meet the defended self first, warmth before the "
            "looking. Emptiness applied to a bracing body is bypassing.", offset=90)

        program = library.build_program(
            session, ["spinal-series-short"], "cushion-radiance-of-the-self", 20,
        )
        note = ("Green-light before clear-light: feel the hurt raw in the body, "
                "honor the self as radiant, self-compassion first.")
        add("tool", library.program_line(program, note), tool_label="Proposed routine",
            data={
                "warmup_slugs": ["spinal-series-short"],
                "sit_slug": "cushion-radiance-of-the-self",
                "sit_minutes": 20,
                "note": note,
                "program": program,
            }, offset=100)

        if with_pending:
            pending_q = "What do the teachings say about resting after the charge releases?"
            add("tool", pending_q, tool_label="Asking Rigdzin notebook…",
                data={"question": pending_q, "answer": None, "status": "pending"},
                offset=110)

        session.commit()
        return morning.id


# ------------------------------------------------------------------ live mode

def sse_events(body: str):
    for line in body.splitlines():
        if line.startswith("data: "):
            yield json.loads(line[6:])


def run_turn(client, path, payload, label):
    t = time.time()
    r = client.post(path, json=payload)
    if r.status_code != 200:
        sys.exit(f"{label}: HTTP {r.status_code} {r.text[:400]}")
    events = list(sse_events(r.text))
    done = next((e for e in events if e.get("type") == "done"), None)
    if done is None:
        sys.exit(f"{label}: stream ended with no done event (the turn was cut off)")
    text = "".join(e["delta"] for e in events if e.get("type") == "text")
    tools = [e["message"] for e in events if e.get("type") == "tool_done"]
    print(f"\n── {label}  ({time.time() - t:.1f}s)")
    if text.strip():
        print(f"   Sit: {text.strip()[:400]}")
    for m in tools:
        status = (m.get("data") or {}).get("status")
        print(f"   [{m['tool_label']}]{' ' + status if status else ''}: {m['content'][:120]}")
    return done, tools


def wait_for_async_answer(client, session_id, timeout=180):
    """The notebook card should flip pending -> done on its own, and the worker
    should then append an applying reply."""
    deadline = time.time() + timeout
    before = None
    while time.time() < deadline:
        r = client.get(f"/api/morning/sessions/{session_id}/messages")
        msgs = r.json()["messages"]
        if before is None:
            before = len(msgs)
        pending = [m for m in msgs if (m.get("data") or {}).get("status") == "pending"]
        resolved = [m for m in msgs
                    if (m.get("data") or {}).get("status") in ("done", "error")
                    and m.get("tool_label", "").startswith("Asked Rigdzin")]
        if not pending and resolved and len(msgs) > before:
            return msgs, True
        time.sleep(1)
    r = client.get(f"/api/morning/sessions/{session_id}/messages")
    return r.json()["messages"], False


def run_live(args):
    from fastapi.testclient import TestClient
    from app.server import app

    failures = []
    with TestClient(app) as client:
        done, tools = run_turn(
            client, "/api/morning/sessions", {"timezone": args.timezone}, "greeting")
        session_id = None
        r = client.get("/api/morning/sessions")
        session_id = r.json()["sessions"][-1]["id"]

        done, tools = run_turn(
            client, f"/api/morning/sessions/{session_id}/chat",
            {"message": args.message, "timezone": args.timezone}, "check-in")

        asked = [m for m in tools if "Rigdzin" in (m.get("tool_label") or "")]
        if not asked:
            failures.append("the model never asked Rigdzin — nothing to test the async path with")
        else:
            card = asked[0]
            if (card.get("data") or {}).get("status") != "pending":
                failures.append(f"notebook card should start pending, got "
                                f"{(card.get('data') or {}).get('status')!r}")
            proposed_early = [m for m in tools if m.get("tool_label") == "Proposed routine"]
            if proposed_early:
                failures.append("model proposed a routine in the same turn it asked "
                                "Rigdzin — it was told to hold that for the resumed turn")

            print("\n── waiting for the background answer + resumed turn")
            msgs, ok = wait_for_async_answer(client, session_id)
            if not ok:
                failures.append("the pending card never resolved into an applying reply")
            for m in msgs[-4:]:
                status = (m.get("data") or {}).get("status")
                label = m.get("tool_label") or m["role"]
                print(f"   [{label}]{' ' + status if status else ''}: {m['content'][:200]}")

    print("\n" + "=" * 60)
    if failures:
        print("FAIL")
        for f in failures:
            print("  ✗ " + f)
        return 1
    print("PASS — greeting, async Rigdzin ask, background answer, applying reply")
    return 0


# ---------------------------------------------------------- second round

def seed_after_sit(user_id):
    """Today's session up to the first sit: check-in, a practice the model added,
    the routine it proposed, and the sit marker. Verbatim from 2026-09-18."""
    from sqlmodel import Session
    from app.db import engine
    from app import library
    from app.models import MorningMessage, MorningSession

    with Session(engine) as session:
        morning = MorningSession(user_id=user_id)
        session.add(morning)
        session.commit()
        session.refresh(morning)
        t0 = datetime.now(tz.utc) - timedelta(minutes=50)

        def add(role, content, *, tool_label=None, data=None, offset=0):
            session.add(MorningMessage(
                session_id=morning.id, role=role, content=content,
                tool_label=tool_label, data=data,
                created_at=t0 + timedelta(seconds=offset),
            ))

        add("assistant",
            "Morning. Last time you named the fear sitting in your gut and the pull to go "
            "panoramic to avoid it — but you never came back to say whether you sat with "
            "it. How are things this morning — body, energy, mood?", offset=0)
        add("user",
            "I think today I want to do:\n1. a 10-minute bioenergetic warm-up\n2. 10 minutes "
            "of concentration\n3. 15 minutes of sitting with my feelings, letting myself "
            "think wherever my brain goes, that kind of thing\nCan you put that together "
            "for me?", offset=40)
        add("assistant",
            "Happy to — that's basically the two-phase structure you liked on the 9th, "
            "gather then release, just with feelings as the second phase instead of "
            "effortlessness.\n\nOne thing before I pick the warm-up, since the bioenergetic "
            "ones each fit a different state: how's the body this morning — flat and "
            "blocked, wired and buzzing, or tight and controlled?", offset=50)
        add("user",
            "Residual anxiety and pain in the heart. I think there's repressed anger and "
            "grief, and maybe some despair about my relationship, and also residual stress "
            "and overwhelm from the week. That said, I just got a bunch of stuff done "
            "today. I've been treating myself really well, taking care of myself, so I do "
            "feel well-resourced and smooth today.", offset=120)
        add("assistant",
            "Well-resourced and smooth, with heart pain and repressed anger and grief "
            "underneath — that's actually the right configuration for going toward it.\n\n"
            "For the warm-up, given the heart pain and what sounds like an armored chest, "
            "I'd go with the shake-fold-diaphragm sequence. Let me build your two-phase sit "
            "as its own practice so the phases are marked.", offset=140)

        sit = library.create_component(
            session, kind="unguided", name="Gather, then feel",
            summary=("Two-phase silent sit: first a stretch of concentration to gather the "
                     "mind (\"not now, return\"), then a longer stretch of open sitting with "
                     "feelings, letting the mind and heart go where they go. Reach for it on "
                     "a well-resourced morning when there's emotional material waiting and "
                     "concentration is worth building first."),
            steps=[
                {"title": "Gather", "duration_s": 600, "bell": "soft",
                 "text": "Concentration on the breath or whole body. Thoughts get 'not now, "
                         "return.' Build continuity of attention."},
                {"title": "Feel", "duration_s": 900, "bell": "long",
                 "text": "Release the technique. Sit with whatever is here — anger, grief, "
                         "despair, stress. Let the mind and heart go where they go; stay in "
                         "the body as much as the story."},
            ],
            source="llm",
        )
        add("tool", sit.summary, tool_label=f"Added to library: {sit.name}", offset=141)

        program = library.build_program(session, ["bioenergetics-cue-card"], sit.slug, 25)
        note = ("Well-resourced day, heart material waiting: open the chest, gather for "
                "10, then let it all come for 15.")
        add("tool", library.program_line(program, note), tool_label="Proposed routine",
            data={"warmup_slugs": ["bioenergetics-cue-card"], "sit_slug": sit.slug,
                  "sit_minutes": 25, "note": note, "program": program}, offset=144)
        add("assistant",
            "There it is — a soft bell marks the switch from gathering to feeling. Go "
            "gently with the heart.", offset=147)
        add("sit", "25", data={"program": program}, offset=600)
        session.commit()
        return morning.id


SECOND_ROUND_MESSAGE = (
    "Really nice, thank you. Smooth and fairly concentrated. The warmup adds a lot. I was "
    "exploring surrendering to the feelings after intellectually briefly checking that I "
    "was in the View, and it feels much more fruitful and rich and warm that way. It also "
    "feels more opened to emotions. I'd like to try another 15m of surrendering to the "
    "feeling of the View."
)


def run_second_round(args, user_id):
    """Pass iff every run answers the request for another round with a real
    propose_program call and no bracketed pseudo-card in the prose. Asking
    Rigdzin first is fine: then the proposal comes in the resumed turn."""
    from fastapi.testclient import TestClient
    from app.server import app

    failures = []
    with TestClient(app) as client:
        for i in range(args.runs):
            session_id = seed_after_sit(user_id)
            r = client.post(f"/api/morning/sessions/{session_id}/chat",
                            json={"message": SECOND_ROUND_MESSAGE, "timezone": args.timezone})
            if r.status_code != 200:
                sys.exit(f"run {i + 1}: HTTP {r.status_code} {r.text[:400]}")
            events = list(sse_events(r.text))
            asked = any(e.get("type") == "tool_done"
                        and "Rigdzin" in e["message"]["tool_label"] for e in events)
            if asked:
                msgs, ok = wait_for_async_answer(client, session_id)
                if not ok:
                    failures.append(f"run {i + 1}: asked Rigdzin but the resumed turn never came")
            else:
                msgs = client.get(f"/api/morning/sessions/{session_id}/messages").json()["messages"]

            last_sit = max(k for k, m in enumerate(msgs) if m["role"] == "sit")
            after = msgs[last_sit + 1:]
            tools = [m["tool_label"] for m in after if m["role"] == "tool"]
            prose = "\n".join(m["content"] for m in after if m["role"] == "assistant")
            print(f"\n── run {i + 1}")
            print(f"   tools: {tools or 'none'}")
            print(f"   Sit: {prose.strip()[:300]}")
            if "Proposed routine" not in tools:
                failures.append(f"run {i + 1}: no propose_program call ({tools or 'no tools'})")
            if "[" in prose:
                failures.append(f"run {i + 1}: bracketed text in the reply: "
                                f"{prose[prose.index('['):][:80]!r}")

    print("\n" + "=" * 60)
    if failures:
        print("FAIL")
        for f in failures:
            print("  ✗ " + f)
        return 1
    print(f"PASS — {args.runs} run(s): another round was proposed as a card, not as text")
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = p.add_mutually_exclusive_group()
    mode.add_argument("--canned", action="store_true",
                      help="seed a fixture session, no model calls (default)")
    mode.add_argument("--live", action="store_true",
                      help="drive the real endpoints with the notebook stubbed")
    mode.add_argument("--second-round", action="store_true",
                      help="after a logged sit, ask for another round; expect a tool call")
    p.add_argument("--runs", type=int, default=1,
                   help="second-round: how many times to run it (the model is stochastic)")
    p.add_argument("--pending", action="store_true",
                   help="canned: leave a pending Rigdzin card in the thread")
    p.add_argument("--keep", action="store_true",
                   help="keep previous eval sessions instead of clearing them")
    p.add_argument("--notebook-delay", type=float, default=0,
                   help="seconds the stubbed notebook takes to answer")
    p.add_argument("--notebook-fail", action="store_true",
                   help="make the stubbed notebook fail, to exercise that path")
    p.add_argument("--message", default=(
        "Relationship conflict this morning. My relative self is the object of "
        "contempt and I keep bypassing the hurt into emptiness. What do the "
        "teachings say about holding it with compassion instead?"))
    p.add_argument("--timezone", default="America/Los_Angeles")
    p.add_argument("--force", action="store_true",
                   help="allow a DATABASE_URL whose name lacks 'eval'")
    args = p.parse_args()

    db = prepare_env(args)
    user_id = setup_db()
    if not args.keep:
        reset_sessions()

    print(f"db      {db}")
    print(f"user    {EVAL_USER}")
    print(f"journal {os.environ['WAKE_UP_LOG']}")
    print(f"notebook {os.environ['NOTEBOOKLM_BIN']}"
          + (f" (+{args.notebook_delay}s)" if args.notebook_delay else ""))

    if args.live:
        return run_live(args)
    if args.second_round:
        return run_second_round(args, user_id)

    session_id = seed_canned(user_id, args.pending)
    print(f"\nseeded canned session {session_id}")
    print("\nlook at it (pass WAKE_UP_LOG too, or a journal write from the page "
          "lands in the real notes):")
    print(f"  DATABASE_URL={db} MORNING_USERNAME={EVAL_USER} \\")
    print(f"    WAKE_UP_LOG={os.environ['WAKE_UP_LOG']} \\")
    print("    uvicorn app.server:app --port 8010")
    print("  open http://127.0.0.1:8010/sit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
