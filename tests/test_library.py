from app.library import (
    SEED_COMPONENTS,
    fixed_s,
    program_line,
    program_summary,
    render_index,
    resolve_program,
)

BY_SLUG = {c["slug"]: c for c in SEED_COMPONENTS}


def seconds(component):
    return [s["duration_s"] for s in component["steps"]]


def test_seed_totals():
    assert fixed_s(BY_SLUG["spinal-series"]["steps"]) == 1560
    assert fixed_s(BY_SLUG["spinal-series-short"]["steps"]) == 540


def test_single_fill_takes_the_whole_sit():
    program = resolve_program(BY_SLUG, [], "unguided-sit", 20)
    assert seconds(program["components"][0]) == [1200]
    assert program["sit_minutes"] == 20


def test_two_fills_split_the_remainder_equally():
    by_slug = dict(BY_SLUG, **{"two-phase": {
        "slug": "two-phase", "kind": "guided", "name": "Two phase",
        "steps": [
            {"title": "Settle", "duration_s": 120},
            {"title": "Open", "duration_s": None},
            {"title": "Rest in it", "duration_s": None},
        ],
    }})
    program = resolve_program(by_slug, [], "two-phase", 20)
    assert seconds(program["components"][0]) == [120, 540, 540]


def test_odd_remainder_lands_on_the_last_fill():
    by_slug = dict(BY_SLUG, **{"odd": {
        "slug": "odd", "kind": "guided", "name": "Odd",
        "steps": [{"title": "A", "duration_s": None}, {"title": "B", "duration_s": None}],
    }})
    program = resolve_program(by_slug, [], "odd", 5)
    assert seconds(program["components"][0]) == [150, 150]
    program = resolve_program(by_slug, [], "odd", 7)
    assert sum(seconds(program["components"][0])) == 420


def test_warmup_nulls_stay_manual():
    by_slug = dict(BY_SLUG, **{"manual": {
        "slug": "manual", "kind": "warmup", "name": "Manual",
        "steps": [{"title": "Stretch", "duration_s": None}, {"title": "Breathe", "duration_s": 60}],
    }})
    program = resolve_program(by_slug, ["manual"], "unguided-sit", 20)
    assert seconds(program["components"][0]) == [None, 60]


def test_program_keeps_the_original_component_untouched():
    resolve_program(BY_SLUG, [], "unguided-sit", 20)
    assert BY_SLUG["unguided-sit"]["steps"][0]["duration_s"] is None


def test_summary_and_line():
    program = resolve_program(BY_SLUG, ["spinal-series-short"], "unguided-sit", 20)
    assert program_summary(program) == "after: Spinal Energy Series, abbreviated (9 min)"
    assert program_line(program, "stiff shoulders") == (
        "Spinal Energy Series, abbreviated (9 min) → Unguided sit (20 min) — stiff shoulders"
    )
    assert program_summary(resolve_program(BY_SLUG, [], "unguided-sit", 20)) == ""


def test_index_lists_every_component_with_its_length():
    text = render_index([
        {"kind": c["kind"], "slug": c["slug"], "name": c["name"], "summary": c["summary"], "steps": c["steps"]}
        for c in SEED_COMPONENTS
    ])
    assert "Spinal Energy Series, abbreviated [spinal-series-short] (9 min)" in text
    assert "Basic Spinal Energy Series [spinal-series] (26 min)" in text
    assert "Unguided sit [unguided-sit] (any length)" in text
    assert text.index("Warm-ups") < text.index("Sits:")


def test_index_duration_when_fixed_steps_precede_a_fill():
    text = render_index([{
        "kind": "guided", "slug": "body-scan-then-sit", "name": "Body scan then sit", "summary": "x",
        "steps": [{"title": "Scan", "duration_s": 300}, {"title": "Sit", "duration_s": None}],
    }])
    assert "Body scan then sit [body-scan-then-sit] (5 min + the chosen length)" in text


def test_index_duration_under_a_minute_stays_in_seconds():
    text = render_index([{
        "kind": "warmup", "slug": "three-breaths", "name": "Three breaths", "summary": "x",
        "steps": [{"title": "Breathe", "duration_s": 30}],
    }])
    assert "Three breaths [three-breaths] (30 s)" in text
