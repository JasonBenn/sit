from unittest.mock import patch

from app import recordings

INDEX = [
    {"id": "rec-emptiness-of-thought", "title": "Emptiness of Thought",
     "collection": "Rigdzin recordings", "duration_s": 1095, "hosted": True,
     "summary": "Three investigations of thought itself.",
     "component_slugs": ["emptiness-of-thought"]},
    {"id": "jhourney-jhana-1", "title": "Jhana 1", "collection": "Jhourney retreat",
     "duration_s": 2400, "hosted": True, "summary": "Access concentration on the breath.",
     "component_slugs": []},
    {"id": "burbea-metta", "title": "Metta (Guided Meditation)", "collection": "Burbea",
     "duration_s": 3000, "hosted": False, "summary": "Lovingkindness, phrase by phrase.",
     "component_slugs": []},
]


class FakeResult:
    def __init__(self, rows):
        self.rows = rows

    def all(self):
        return self.rows


class FakeSession:
    """`find` only reads listens and sits; the queries are thin enough to stub."""

    def __init__(self, listens=(), programs=()):
        self.results = [list(listens), list(programs)]

    def exec(self, statement):
        return FakeResult(self.results.pop(0))


def test_keywords_drop_short_and_common_words():
    assert recordings.keywords("settling a scattered anxious mind") == [
        "sett", "scat", "anxi", "mind",
    ]


def test_keywords_stem_by_prefix():
    keys = recordings.keywords("settling")
    assert recordings.snippets(["Let the body settle here."], keys) == [
        "Let the body settle here."
    ]


def test_snippets_take_at_most_two_trimmed_lines():
    lines = [f"the breath, line {i}" for i in range(5)] + ["nothing here"]
    found = recordings.snippets(lines, ["brea"])
    assert found == ["the breath, line 0", "the breath, line 1"]

    long_line = "breath " * 60
    assert len(recordings.snippets([long_line], ["brea"])[0]) <= recordings.SNIPPET_WIDTH


def test_recent_from_listens_and_programs():
    programs = [{"components": [
        {"slug": "spinal-series-short", "kind": "warmup"},
        {"slug": "emptiness-of-thought", "kind": "guided"},
    ]}]
    assert recordings.recent_from(["burbea-metta"], programs, INDEX) == {
        "burbea-metta", "rec-emptiness-of-thought",
    }


def test_recent_from_ignores_unguided_components():
    programs = [{"components": [{"slug": "emptiness-of-thought", "kind": "unguided"}]}]
    assert recordings.recent_from([], programs, INDEX) == set()


def test_parse_choices_drops_unknown_ids():
    text = 'Sure:\n[{"id": "jhourney-jhana-1", "why": "steadies"}, {"id": "nope", "why": "x"}]'
    assert recordings.parse_choices(text, {"jhourney-jhana-1"}) == [
        {"id": "jhourney-jhana-1", "why": "steadies"}
    ]


def test_parse_choices_caps_at_four():
    ids = {f"r{i}" for i in range(6)}
    text = "[" + ", ".join(f'{{"id": "r{i}", "why": "w"}}' for i in range(6)) + "]"
    assert len(recordings.parse_choices(text, ids)) == 4


def test_parse_choices_on_malformed_output():
    assert recordings.parse_choices("nothing fits this morning", {"a"}) == []
    assert recordings.parse_choices('[{"id": "a", "why": ]', {"a"}) == []
    assert recordings.parse_choices('{"id": "a"}', {"a"}) == []


def _reply(text):
    class Block:
        type = "text"

    block = Block()
    block.text = text

    class Response:
        content = [block]

    return Response()


def _find(inquiry, reply, session=None, **kwargs):
    with patch.object(recordings, "RECORDINGS", INDEX), \
            patch.object(recordings, "TRANSCRIPTS", {}), \
            patch("anthropic.Anthropic") as client:
        client.return_value.messages.create.return_value = _reply(reply)
        result = recordings.find(session or FakeSession(), inquiry, **kwargs)
        return result, client.return_value.messages.create.call_args


def test_find_returns_full_records_in_the_selector_order():
    reply = ('[{"id": "jhourney-jhana-1", "why": "steadies a scattered mind"}, '
             '{"id": "rec-emptiness-of-thought", "why": "looks at the looping"}]')
    choices, _ = _find("a scattered looping mind", reply)
    assert [c["id"] for c in choices] == ["jhourney-jhana-1", "rec-emptiness-of-thought"]
    assert choices[0] == {
        "id": "jhourney-jhana-1", "title": "Jhana 1", "collection": "Jhourney retreat",
        "duration_s": 2400, "summary": "Access concentration on the breath.",
        "why": "steadies a scattered mind", "component_slugs": [],
    }
    assert choices[1]["component_slugs"] == ["emptiness-of-thought"]


def test_find_excludes_unhosted_recent_and_overlong_candidates():
    session = FakeSession(listens=["jhourney-jhana-1"], programs=[])
    _, call = _find("breath", "[]", session=session, max_minutes=30)
    prompt = call.kwargs["messages"][0]["content"]
    assert "rec-emptiness-of-thought" in prompt      # 18 min, unheard, hosted
    assert "jhourney-jhana-1" not in prompt          # listened to
    assert "burbea-metta" not in prompt              # not hosted


def test_find_skips_the_model_when_nothing_is_left():
    session = FakeSession(listens=[], programs=[])
    with patch.object(recordings, "RECORDINGS", INDEX), patch("anthropic.Anthropic") as client:
        assert recordings.find(session, "breath", max_minutes=1) == []
    client.assert_not_called()


def test_tool_result_text():
    choices = [
        {"title": "Jhana 1", "collection": "Jhourney retreat", "duration_s": 2400,
         "why": "steadies a scattered mind", "component_slugs": []},
        {"title": "Emptiness of Thought", "collection": "Rigdzin recordings",
         "duration_s": 1095, "why": "looks at the looping",
         "component_slugs": ["emptiness-of-thought"]},
    ]
    text = recordings.tool_result_text(choices)
    assert text.splitlines()[0] == "Jhana 1 (40 min, Jhourney retreat): steadies a scattered mind"
    assert ("Emptiness of Thought (18 min, Rigdzin recordings): looks at the looping "
            "— also cut as [emptiness-of-thought]") in text
    assert recordings.RESULT_NOTE in text


def test_tool_result_text_with_no_choices():
    assert recordings.tool_result_text([]) == recordings.NO_FIT


def test_replay_suffix():
    data = {"choices": [{"id": "a", "title": "Jhana 1"}, {"id": "b", "title": "Metta"}],
            "played": None}
    assert recordings.replay_suffix(data) == " → Jhana 1; Metta"
    assert recordings.replay_suffix(dict(data, played="b")) == \
        " → Jhana 1; Metta — played: Metta"
    assert recordings.replay_suffix({"choices": [], "played": None}) == " → nothing fit"
