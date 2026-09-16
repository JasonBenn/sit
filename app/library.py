"""Practice library: components (warm-ups and sits), the seeds, and the resolver
that turns a choice of slugs into a program the runner can play without thinking.

A program is stored resolved — fills applied, media URLs final — so editing or
deleting a component later never changes what a past morning recorded.
"""
from typing import Optional
import json
import os
import re

from sqlmodel import Session, select

from app.models import Component

KIND_ORDER = {"warmup": 0, "guided": 1, "unguided": 2}
KIND_HEADINGS = [("warmup", "Warm-ups (before the sit):"), ("guided", "Guided sits:"), ("unguided", "Sits:")]

GUIDANCE = """The bracketed handle after each name is the slug propose_program takes. \
Any of these can be suggested from the check-in; the summaries say when each fits."""


def _img(slug: str, n: str) -> dict:
    return {"type": "image", "src": f"/static/routines/{slug}/{n}.png"}


SPINAL_SERIES_STEPS = [
    {
        "title": "1. Spinal flex, holding the ankles",
        "text": "Sit in easy pose. Hold the ankles with both hands. Inhale, flex the spine forward and lift the chest; exhale, flex the spine back. Keep the head level so it doesn't flip-flop. 108 times, then inhale and hold briefly.",
        "media": _img("spinal-series", "01"),
        "duration_s": 180,
        "bell": "soft",
    },
    {"title": "Rest", "text": "Sit still, breathe normally.", "duration_s": 60, "bell": "soft"},
    {
        "title": "2. Spinal flex on the heels",
        "text": "Sit on the heels, hands flat on the thighs. Inhale flexing forward, exhale flexing back. Mentally: 'Sat' on the inhale, 'Nam' on the exhale. 108 times.",
        "media": _img("spinal-series", "02"),
        "duration_s": 180,
    },
    {"title": "Rest", "text": "Sit still, breathe normally.", "duration_s": 120},
    {
        "title": "3. Spinal twist",
        "text": "Easy pose. Grasp the shoulders, fingers in front, thumbs in back. Inhale twisting left, exhale twisting right, breathing long and deep. 26 times, then inhale facing forward.",
        "media": _img("spinal-series", "03"),
        "duration_s": 120,
    },
    {"title": "Rest", "text": "Sit still, breathe normally.", "duration_s": 60},
    {
        "title": "4. Bear grip see-saw",
        "text": "Lock the fingers in bear grip at the heart center (fingers hooked together, one palm facing out, one in). See-saw the elbows, breathing long and deep with the motion. 26 times; then inhale, exhale, and pull on the lock.",
        "media": _img("spinal-series", "04"),
        "duration_s": 120,
    },
    {"title": "Rest", "text": "Sit still, breathe normally.", "duration_s": 30},
    {
        "title": "5. Upper spine flex, holding the knees",
        "text": "Easy pose. Grasp the knees firmly, elbows straight. Inhale flexing the upper spine forward, exhale flexing back. 108 times.",
        "media": _img("spinal-series", "05"),
        "duration_s": 180,
    },
    {"title": "Rest", "text": "Sit still, breathe normally.", "duration_s": 60},
    {
        "title": "6. Shoulder shrugs",
        "text": "Shrug both shoulders up with the inhale, down with the exhale. Near the end, inhale and hold 15 seconds with the shoulders pressed up, then relax them.",
        "media": _img("spinal-series", "06"),
        "duration_s": 120,
    },
    {
        "title": "7. Neck rolls",
        "text": "Roll the neck slowly to the right 5 times, then to the left 5 times. Inhale and pull the neck straight.",
        "media": _img("spinal-series", "07"),
        "duration_s": 60,
    },
    {
        "title": "8. Bear grip at the throat, with root lock",
        "text": "Bear grip at throat level. Inhale and apply mul bandh (root lock: contract the anus, sex organ and navel); exhale and apply it again. Raise the hands above the head and repeat: inhale, lock; exhale, lock. Three full cycles.",
        "media": _img("spinal-series", "08"),
        "duration_s": 90,
    },
    {
        "title": "9. Sat Kriya",
        "text": "Sit on the heels, arms stretched overhead, fingers interlaced except the index fingers, which point straight up. Say 'Sat' and pull the navel in; say 'Nam' and release. Continue steadily; at the end inhale and squeeze the energy from the base of the spine to the top of the skull.",
        "media": _img("spinal-series", "09"),
        "duration_s": 180,
        "bell": "long",
    },
]

# Same nine exercises, a minute each, no rests — the pace is the clock rather
# than a rep count.
SPINAL_SERIES_SHORT_STEPS = [
    {
        "title": "1. Spinal flex, holding the ankles",
        "text": "Sit in easy pose. Hold the ankles with both hands. Inhale, flex the spine forward and lift the chest; exhale, flex the spine back. Keep the head level so it doesn't flip-flop. Steadily for the minute, then inhale and hold briefly.",
        "media": _img("spinal-series", "01"),
        "duration_s": 60,
    },
    {
        "title": "2. Spinal flex on the heels",
        "text": "Sit on the heels, hands flat on the thighs. Inhale flexing forward, exhale flexing back. Mentally: 'Sat' on the inhale, 'Nam' on the exhale. Steadily for the minute.",
        "media": _img("spinal-series", "02"),
        "duration_s": 60,
    },
    {
        "title": "3. Spinal twist",
        "text": "Easy pose. Grasp the shoulders, fingers in front, thumbs in back. Inhale twisting left, exhale twisting right, breathing long and deep. Steadily for the minute, then inhale facing forward.",
        "media": _img("spinal-series", "03"),
        "duration_s": 60,
    },
    {
        "title": "4. Bear grip see-saw",
        "text": "Lock the fingers in bear grip at the heart center (fingers hooked together, one palm facing out, one in). See-saw the elbows, breathing long and deep with the motion. Steadily for the minute; then inhale, exhale, and pull on the lock.",
        "media": _img("spinal-series", "04"),
        "duration_s": 60,
    },
    {
        "title": "5. Upper spine flex, holding the knees",
        "text": "Easy pose. Grasp the knees firmly, elbows straight. Inhale flexing the upper spine forward, exhale flexing back. Steadily for the minute.",
        "media": _img("spinal-series", "05"),
        "duration_s": 60,
    },
    {
        "title": "6. Shoulder shrugs",
        "text": "Shrug both shoulders up with the inhale, down with the exhale. Steadily for the minute; near the end, inhale and hold 15 seconds with the shoulders pressed up, then relax them.",
        "media": _img("spinal-series", "06"),
        "duration_s": 60,
    },
    {
        "title": "7. Neck rolls",
        "text": "Roll the neck slowly to the right for half the minute, then to the left. Inhale and pull the neck straight.",
        "media": _img("spinal-series", "07"),
        "duration_s": 60,
    },
    {
        "title": "8. Bear grip at the throat, with root lock",
        "text": "Bear grip at throat level. Inhale and apply mul bandh (root lock: contract the anus, sex organ and navel); exhale and apply it again. Raise the hands above the head and repeat: inhale, lock; exhale, lock. Cycle steadily for the minute.",
        "media": _img("spinal-series", "08"),
        "duration_s": 60,
    },
    {
        "title": "9. Sat Kriya",
        "text": "Sit on the heels, arms stretched overhead, fingers interlaced except the index fingers, which point straight up. Say 'Sat' and pull the navel in; say 'Nam' and release. Steadily for the minute; at the end inhale and squeeze the energy from the base of the spine to the top of the skull.",
        "media": _img("spinal-series", "09"),
        "duration_s": 60,
        "bell": "long",
    },
]

# From Logs/Bioenergetics.md (June 2026): Lowen-derived pre-sit unblocking, v2.1
# cue card. Designed to run from memory, so the cues stay short and the bells
# carry the transitions. The summary carries Jason's own guardrail against it
# becoming a daily should.
BIOENERGETICS_CAUTION = (
    " Offer it sparingly and never as a default — it is meant to stay irregular, and on "
    "some mornings the better move is to skip it and just feel blocked. If a big release "
    "opens, it becomes its own session and the sit waits."
)

def _bio_steps(third: dict) -> list[dict]:
    return [
        {
            "title": "1. Shake",
            "text": "Feet apart, knees soft. Bounce the knees and let the whole body shake — arms, shoulders, jaw. Charging up, not exercising.",
            "duration_s": 60,
        },
        {
            "title": "2. Fold",
            "text": "Hang forward, knees slightly bent. Slowly bend and straighten the knees a few times until the legs start to tremble, then hold and let the shaking have you. Mouth open, keep breathing.",
            "duration_s": 75,
        },
        third,
        {
            "title": "4. Settle",
            "text": "Fold forward again to shake the legs out. Then sit, soften the eyes, a few long exhales. There's no doing this right.",
            "duration_s": 45,
            "bell": "long",
        },
    ]

BIOENERGETICS_STEPS = _bio_steps({
    "title": "3. Diaphragm",
    "text": "Lie back over the bolster at mid-back, solar-plexus level, head and arms dangling. Groan on every exhale, aimed at the band between chest and belly. Don't force air past the block — sensing it is the work. Let the sounds and tears come.",
    "duration_s": 180,
})

BIOENERGETICS_NO_BOLSTER_STEPS = _bio_steps({
    "title": "3. Chair backbend",
    "text": "Sit, arms up, arch back over the chair back so the chest opens. A long 'ahhh' on each exhale. Breathing here won't be easy — that difficulty is the armor. Stay with it rather than forcing the breath.",
    "duration_s": 150,
})

SEED_COMPONENTS = [
    {
        "slug": "spinal-series-short",
        "kind": "warmup",
        "name": "Spinal Energy Series, abbreviated",
        "summary": "Nine one-minute kundalini spinal exercises — flexes, twists, shrugs, neck rolls, Sat Kriya — with no rests, 9 minutes, straight into the sit. The default warm-up: reach for it when the body is stiff or groggy, or the mind is dull and needs to arrive before sitting.",
        "steps": SPINAL_SERIES_SHORT_STEPS,
    },
    {
        "slug": "spinal-series",
        "kind": "warmup",
        "name": "Basic Spinal Energy Series",
        "summary": "The Basic Spinal Energy Series from Sadhana Guidelines at full repetition counts, with rests between exercises — 26 minutes. Reach for it on a long morning, or when the user wants the thorough version rather than the quick one.",
        "steps": SPINAL_SERIES_STEPS,
    },
    {
        "slug": "bioenergetics-cue-card",
        "kind": "warmup",
        "name": "Shake, fold, diaphragm, settle",
        "summary": "Four bioenergetic moves, 6 minutes: shake the whole body loose, fold forward until the legs tremble, lie back over a bolster at mid-back and groan on every exhale, then settle. Reach for it on a flat, low-energy, blocked-up morning, when the chest feels armored and breathing is shallow, or when sitting has been too calming and needs some charge — it raises energy and drops you out of your head. Tears are common and are the work." + BIOENERGETICS_CAUTION,
        "steps": BIOENERGETICS_STEPS,
    },
    {
        "slug": "bioenergetics-no-bolster",
        "kind": "warmup",
        "name": "Shake, fold, chair backbend, settle",
        "summary": "The same four-move bioenergetic warm-up, 5½ minutes, for a morning with no bolster — travel, a bare floor — with the chest opener done backward over a chair instead." + BIOENERGETICS_CAUTION,
        "steps": BIOENERGETICS_NO_BOLSTER_STEPS,
    },
    {
        "slug": "unguided-sit",
        "kind": "unguided",
        "name": "Unguided sit",
        "summary": "Silent sitting for the chosen length, with the intention distilled from the check-in shown on screen. The default sit when nothing specific is called for.",
        "steps": [{"title": "Sit", "duration_s": None, "bell": "long"}],
    },
]


# Seed files: app/seeds/*.json, each a list of components in the same shape as
# SEED_COMPONENTS (kind, slug, name, summary, steps). Longer authored sequences
# live there rather than as Python literals.
SEED_DIR = os.path.join(os.path.dirname(__file__), "seeds")
for _name in sorted(os.listdir(SEED_DIR)):
    if _name.endswith(".json"):
        with open(os.path.join(SEED_DIR, _name)) as _f:
            SEED_COMPONENTS.extend(json.load(_f))


def slugify(name: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", name.lower())).strip("-")


def ensure_seeds(session: Session) -> None:
    """Insert any seed the library is missing. Never overwrites: the seeds are a
    starting point, and the user's edits win."""
    existing = set(session.exec(select(Component.slug)).all())
    for seed in SEED_COMPONENTS:
        if seed["slug"] in existing:
            continue
        session.add(Component(
            slug=seed["slug"], kind=seed["kind"], name=seed["name"],
            summary=seed["summary"], steps_json=seed["steps"], source="seed",
        ))
    session.commit()


def fixed_s(steps: list[dict]) -> int:
    return sum(s["duration_s"] for s in steps if s.get("duration_s") is not None)


def has_fill(steps: list[dict]) -> bool:
    return any(s.get("duration_s") is None for s in steps)


def serialize_component(c: Component) -> dict:
    return {
        "id": str(c.id),
        "slug": c.slug,
        "kind": c.kind,
        "name": c.name,
        "summary": c.summary,
        "steps": c.steps_json,
        "fixed_s": fixed_s(c.steps_json),
        "has_fill": has_fill(c.steps_json),
    }


def list_components(session: Session) -> list[Component]:
    components = session.exec(select(Component)).all()
    # Slug order within a kind: curriculum-coded slugs (gy1-…, py2-…) sort into sequence.
    return sorted(components, key=lambda c: (KIND_ORDER[c.kind], c.slug))


def create_component(
    session: Session, kind: str, name: str, summary: str,
    steps: list[dict], source: str, slug: Optional[str] = None,
) -> Component:
    slug = slug or slugify(name)
    taken = set(session.exec(select(Component.slug)).all())
    if slug in taken:  # a second "Body scan" becomes body-scan-2, not a 500 mid-turn
        n = 2
        while f"{slug}-{n}" in taken:
            n += 1
        slug = f"{slug}-{n}"
    component = Component(
        slug=slug, kind=kind, name=name,
        summary=summary, steps_json=steps, source=source,
    )
    session.add(component)
    session.flush()
    return component


def resolve_program(
    components_by_slug: dict, warmup_slugs: list[str], sit_slug: str, sit_minutes: int,
) -> dict:
    """Snapshot the chosen components with every duration final.

    In a warm-up a null duration stays null — the runner waits for *next*. In the
    sit component it's a fill: the null steps share the seated seconds left over
    after the fixed steps, equally, with the rounding remainder on the last one so
    the component lands exactly on the chosen length."""
    components = []
    for slug in list(warmup_slugs) + [sit_slug]:
        c = components_by_slug[slug]  # unknown slug: let it crash
        steps = [dict(s) for s in c["steps"]]
        if c["kind"] != "warmup":
            fills = [s for s in steps if s.get("duration_s") is None]
            remaining = sit_minutes * 60 - fixed_s(steps)
            for i, step in enumerate(fills):
                step["duration_s"] = remaining // len(fills)
                if i == len(fills) - 1:
                    step["duration_s"] += remaining - (remaining // len(fills)) * len(fills)
        components.append({
            "slug": c["slug"], "kind": c["kind"], "name": c["name"], "steps": steps,
        })
    return {"sit_minutes": sit_minutes, "components": components}


def build_program(
    session: Session, warmup_slugs: list[str], sit_slug: str, sit_minutes: int,
) -> dict:
    by_slug = {
        c.slug: {"slug": c.slug, "kind": c.kind, "name": c.name, "steps": c.steps_json}
        for c in list_components(session)
    }
    return resolve_program(by_slug, warmup_slugs, sit_slug, sit_minutes)


def _length(seconds: int) -> str:
    return f"{round(seconds / 60)} min" if seconds >= 60 else f"{seconds} s"


def _component_length(component: dict) -> str:
    return _length(fixed_s(component["steps"]))


def program_summary(program: dict) -> str:
    """The warm-ups of a program, for the sit marker the model reads:
    `after: Spinal Energy Series, abbreviated (9 min)`. Empty when there are none."""
    warmups = [c for c in program["components"] if c["kind"] == "warmup"]
    if not warmups:
        return ""
    return "after: " + ", ".join(f"{c['name']} ({_component_length(c)})" for c in warmups)


def program_line(program: dict, note: str = "") -> str:
    """One human-readable line for the proposal card:
    `Spinal Energy Series, abbreviated (9 min) → Unguided sit (20 min) — <note>`."""
    line = " → ".join(f"{c['name']} ({_component_length(c)})" for c in program["components"])
    return f"{line} — {note}" if note else line


def _duration_text(steps: list[dict]) -> str:
    fixed, fill = fixed_s(steps), has_fill(steps)
    if not fill:
        return _length(fixed)
    if not fixed:
        return "any length"
    return f"{_length(fixed)} + the chosen length"


def render_index(components: list[dict]) -> str:
    """The `## Practice library` block of the system prompt, grouped by kind."""
    lines = ["## Practice library"]
    for kind, heading in KIND_HEADINGS:
        group = [c for c in components if c["kind"] == kind]
        if not group:
            continue
        lines.append("")
        lines.append(heading)
        for c in group:
            lines.append(f"- {c['name']} [{c['slug']}] ({_duration_text(c['steps'])}): {c['summary']}")
    lines.append("")
    lines.append(GUIDANCE)
    return "\n".join(lines)


def component_index_text(session: Session) -> str:
    return render_index([
        {"kind": c.kind, "slug": c.slug, "name": c.name, "summary": c.summary, "steps": c.steps_json}
        for c in list_components(session)
    ])
