# Practice library and the routine runner

The morning sit is a **program**: an ordered list of **components** drawn from a
library, played back by one **runner** (the full-screen overlay in `morning.html`).
Warm-ups run before the sit; the sit itself is a component too (guided or unguided).
The LLM sees an index of the library in its system prompt, can propose a program
from it, and can add components to it.

## Component

Table `components` (global, no user scoping — single-user app). Model in `app/models.py`,
helpers and seeds in `app/library.py`.

| column | type | notes |
|---|---|---|
| id | UUID | |
| slug | str, unique | stable handle used by tools and the UI, e.g. `spinal-series-short` |
| kind | str | `warmup` \| `guided` \| `unguided` |
| name | str | shown in the menu, TOC, and marker |
| summary | text | one or two sentences: what it is and **when to reach for it**. This is what the LLM reads. |
| steps_json | JSONB | `list[Step]`, below |
| source | str | `seed` \| `llm` \| `user` |
| created_at | timestamptz | |

### Step

```json
{
  "title": "3. Spinal twist",
  "text": "Grasp the shoulders, fingers in front, thumbs in back. Inhale twisting left, exhale twisting right. Long, deep breaths.",
  "media": {"type": "image", "src": "/static/routines/spinal-series/03.png"},
  "duration_s": 60,
  "bell": "soft"
}
```

- `text` and `media` are optional. `media.type` is `image` | `audio` | `video`; `src` is a URL
  (repo-static under `/static/routines/<slug>/`, or absolute). PDFs are an *authoring* input:
  render or extract at ingest, never at runtime.
- `duration_s`: integer seconds, or `null`.
  - In a **warmup**, `null` means manual advance: the runner waits for *next*.
  - In a **guided/unguided** component, `null` means *fill*: the step takes the chosen sit
    length. Several fill steps share it equally after fixed steps are subtracted.
- `bell`: `soft` | `long` | `none`, played when the step ends by timer. Default `soft`.
  The runner always plays `long` when a component ends and at the very end of the program,
  regardless of the last step's flag. Steps skipped with *next* don't bell.

### Program

Built server-side by `library.build_program(warmup_slugs, sit_slug, sit_minutes)` and stored
**resolved** (fills already applied, media URLs final), so the runner is dumb:

```json
{
  "sit_minutes": 20,
  "components": [
    {"slug": "spinal-series-short", "kind": "warmup", "name": "Spinal Energy Series, abbreviated", "steps": [ ... ]},
    {"slug": "unguided-sit", "kind": "unguided", "name": "Unguided sit", "steps": [{"title": "Sit", "duration_s": 1200, "bell": "long"}]}
  ]
}
```

Snapshotted, not referenced: editing or deleting a component later never changes what a past
morning recorded.

## Where it's logged

- `sits.program_json` (JSONB, nullable) — the durable log of the whole routine.
  `duration_seconds` stays the seated minutes only (`sit_minutes * 60`); warm-up time is
  derivable from the program.
- `morning_messages.data` (JSONB, nullable) — structured payload for messages that need one:
  - role `sit`: `{"program": <program>}` (same object as `sits.program_json`). `content` stays
    the minutes as a string. Old sit markers have `data = null`; the UI treats that as a bare
    unguided program of `content` minutes.
  - role `tool`, `tool_label = "Proposed routine"`: `{"warmup_slugs": [...], "sit_slug": "...", "sit_minutes": 20}`.

The prompt renders a sit marker with its warm-ups so the model knows what happened:
`[A 20-minute sit happens here, after: Spinal Energy Series, abbreviated (9 min).]`

## API (`app/routers/morning.py`)

- `GET /api/morning/components` → `{"components": [{id, slug, kind, name, summary, steps, fixed_s, has_fill}]}`
  ordered warmup, guided, unguided, then by name. `fixed_s` = sum of fixed durations; `has_fill`
  = any null-duration step (in a sit component: it stretches to the chosen minutes).
- `POST /api/morning/components` body `{kind, name, summary, steps, slug?}` → creates one (source
  `user`); slug derived from the name if omitted. Same code path the LLM tool uses.
- `POST /api/morning/sessions/{id}/sits` body
  `{sit_minutes, timezone, warmup_slugs: [], sit_slug: "unguided-sit"}` → logs the sit with
  `program_json`, pins the marker with `data.program`. Response `{"message": ...}` as before.
- `GET /api/morning/sessions/{id}/intention` — unchanged; the runner streams it into the sit step.

## LLM tools

- `create_component(kind, name, summary, steps)` — persists to the library; chip label
  `Added to library: <name>`; the system prompt is rebuilt afterwards so the index is current
  within the same turn.
- `propose_program(warmup_slugs, sit_slug, sit_minutes, note)` — persists a tool message
  (label `Proposed routine`, content = one human-readable line, `data` = the params). The UI
  renders it as a card with a **Start** button: it logs the sit with those params and opens the
  runner, and also sets the sit-row selection to match.

## Prompt index

`build_system_prompt` appends a `## Practice library` section generated from the table:

```
Warm-ups (before the sit):
- Spinal Energy Series, abbreviated (9 min): nine one-minute kundalini spinal exercises … reach for it when …
- Basic Spinal Energy Series (26 min): …
Sits:
- Unguided sit (any length): silent sitting with the intention distilled from the check-in. The default.
```

followed by guidance: suggest a program when the check-in points at one; offer it with
`propose_program` rather than describing it; when the user describes a practice that isn't in
the library, add it with `create_component` (ask about durations if they didn't say).

## Runner (in `morning.html`)

One overlay plays any program.

- **Left: table of contents.** Component names as headers, step titles beneath. Current step
  emphasized, others grayed; finished steps dimmed further. Click any step to jump to it
  (jumping doesn't bell). Under 900px the TOC collapses to a `3 / 12` button that opens it as a
  sheet.
- **Center.** For a warm-up step: image (if any, capped ~40vh), title, text, and the step
  countdown at ~96px. For the sit step: the existing look — countdown at 190px, streamed
  intention in italic serif beneath (the intention is prefetched when the runner opens so it's
  ready when the sit begins).
- **Controls, bottom.** `‹ prev` · `pause` / `resume` · `next ›` · `end`. Tapping the center
  toggles pause; hint text says so. Keyboard: space, arrow keys, escape.
- **Timing** is wall-clock: each step records its start time and accumulated pause; remaining
  time is recomputed every 250 ms from `Date.now()`, so a backgrounded tab doesn't drift.
- **Bells** come from the existing oscillator chime. Soft = ~1.2 s at 528 Hz; long = the current
  4 s decay. The `AudioContext` is created on the start tap (iOS autoplay rule) and reused.
  Play only when `document.visibilityState === 'visible'`.
- **Wake lock** (`navigator.wakeLock.request('screen')`) is taken on start, re-taken on
  `visibilitychange` → visible, released on end.
- Manual-advance steps (warm-up steps with `duration_s: null`) show `—` for the countdown and
  the hint `next when ready`.

## Choosing a program (sit row)

Duration chips stay. A **routine** button before *Add sit* shows the current choice
(`just sit`, or `Spinal, abbreviated → sit`) and opens a small panel:

- *Before the sit*: `none` + every warmup, radio.
- *The sit*: every guided/unguided component, radio; default `unguided-sit`.

The choice persists in `localStorage`. *Add sit* sends it. The sit marker in the conversation
reads `Spinal Energy Series, abbreviated · 20-minute sit` with the `▶ start` button.

## Adding a routine from media

Images: put files under `app/static/routines/<slug>/` and reference them from steps. PDFs:
render pages (`pdftoppm`) or extract embedded images (`pdfimages -j`), then crop; the spinal
series drawings came from the Sadhana Guidelines PDF this way. Audio and video use the same
`media` field; the runner renders them with native `<audio>`/`<video>` controls, autoplaying
when the step starts.
