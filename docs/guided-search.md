# Guided-meditation search and the player

The morning companion can look for a guided meditation that fits the check-in with one tool
call, `find_guided_meditations`. Under the hood it searches the transcripts of every guided
recording in Jason's library, drops what he has heard in the last 30 days, and returns zero to
four varied choices. The UI renders them as a card; pressing play on a choice loads the
recording into the **player**, a docked audio widget at the bottom of the chat pane.

This is separate from the practice library (`docs/practice-library.md`): library components are
hand-cut clips played by the runner; recordings here are the *whole* source files, playable
directly. A recording that also has a cut component says so, and the model can then offer
that component with `propose_program` instead.

## Recordings

Source of truth is the Meditations tree: `<root>/<drive folder>/<title>.mp3` with a Whisper
`<title>_transcription.json` beside every recording. On nose the root is the rclone mirror of
Google Drive at `/opt/sit-media/drive/Meditations` (hourly, `~/.claude/nose/drive-mirror.sh`);
on the Mac it is `~/code/meditation-clipper/Meditations`, readable only through the FDA tmux
server (`tmux -L fda run-shell`). The 13 GiB `Jhourney Recordings` folder is never a source.

`scripts/build_recordings.py` builds the index and the transcripts. It:

1. Reads every `*_transcription.json` in the eight collection folders and keeps the guided
   ones:
   - Rigdzin course folders (`Rigdzin - Advanced`, `Rigdzin - Intermeditate`): title matches
     `^\d{3}m` (m = meditation; q/t are Q&A and talks).
   - `Rigdzin-Intro`: title starts with `Med：`.
   - `Ridgzin - Recordings`, `Rigdzin Charity 2025-01-03`, `My clips`: every recording.
   - `Jhourney - in-person retreat 12 Nov`: everything except the `EXTRA` tracks, the
     exercise/instruction tracks, and transcripts that degenerated into fragments over silence.
   - `Burbea - Jhanas`: only the two titled `(Guided Meditation)`.
2. Assigns each a stable `id`: slugified title, prefixed by a short folder tag
   (`rec-`, `charity-`, `adv-`, `int-`, `intro-`, `jhourney-`, `burbea-`, `clips-`).
3. Turns the JSON into `[mm:ss] line` text the same way meditation-clipper's
   `export_notebooklm.py` does (one line per sentence timed by its first word, else per
   segment) and writes it to `MEDIA_DIR/transcripts/<id>.txt` — in place on nose, staged and
   rsynced from the Mac.
4. Reads the mp3's duration with `ffprobe`; `hosted: false` when the file is missing or empty.
   Durations already in the index are reused (`--reprobe` re-reads them).
5. Summarizes each recording once with `claude-sonnet-5` from its transcript: two sentences,
   what the practice is and when to reach for it, in the voice of the library summaries.
   Summaries are cached in the index so reruns only summarize new recordings.
6. Maps recordings to library components: an entry of any `scripts/*_manifest.json` whose
   `source` is `<folder>/<title>.mp3` gives the recording a `component_slugs` list.
7. Gives each a `name`, the title a human would recognize — most raw titles are course codes
   or export filenames (`102m dorje`, `Med： emptiness - body (Wed 5) [7c37…]`). A recording
   with components takes the manifest name of its `-full` variant, minus the ` (full)` /
   ` (short)` suffix; otherwise the title with the course code, the `Med：` prefix, bracketed
   hashes, parentheticals, `⭐️` and `_modified` stripped, and the first letter capitalized.
8. Writes `app/recordings.json` — committed, ~136 entries, no transcript text:

```json
{"id": "rec-emptiness-of-thought-20min-stages23", "title": "Emptiness of Thought - 20min(Stages23)",
 "folder": "Ridgzin - Recordings", "name": "Emptiness of thought", "collection": "Rigdzin recordings",
 "duration_s": 1095, "hosted": true,
 "summary": "Three investigations of thought itself … Reach for it when the mind is busy and looping.",
 "component_slugs": ["emptiness-of-thought"]}
```

Audio is never copied. `GET /media/recordings/<id>.mp3` (declared in `app/server.py` ahead of
the `/media` static mount) resolves the id through the index to
`MEDIA_DIR/drive/Meditations/<folder>/<title>.mp3` and serves it with `FileResponse`, which
answers Range requests for the scrubber. Ids stay in URLs so the Drive names never do.

`collection` is a human label per folder: Rigdzin recordings, Rigdzin charity retreat, Rigdzin
advanced course, Rigdzin intermediate course, Rigdzin intro retreat, Jhourney retreat, Burbea,
Jason's clips.

## Search (`app/recordings.py`)

Loaded at import: the index, and each hosted recording's transcript from
`MEDIA_DIR/transcripts/` (missing file → the recording is searchable by summary only).

`find(session, inquiry, max_minutes=None, now=None) -> list[dict]`:

1. **Recent** = recordings heard in the last 30 calendar days: rows of `listens` (below) plus
   guided component slugs in `sits.program_json` (started in the window), mapped back through
   `component_slugs`.
2. **Candidates** = hosted recordings, minus recent, minus those over `max_minutes` when given.
3. **Snippets**: for each candidate, up to two transcript lines that contain a keyword of the
   inquiry (words of four or more letters, stemmed crudely by prefix), trimmed to ~160 chars.
   This is the grep; it gives the selector evidence beyond the summary.
4. **Selection**: one `claude-sonnet-5` call. Input: the inquiry, and every candidate as
   `id · title · collection · N min · summary · snippets`. Instruction: choose zero to four
   that would genuinely serve the inquiry, spanning *different* approaches (not four
   emptiness sits), preferring variety across collections; return `[]` when nothing fits;
   respond as JSON `[{"id": …, "why": one clause}]`. Parse strictly; unknown ids are dropped.
5. Returns `[{id, name, title, collection, duration_s, summary, why, component_slugs}]` in
   the selector's order.

Tool result text for the model: one line per choice — `name (N min, collection): why`,
with `— also cut as [slug]` when the recording has a component — or
`No guided meditation fits; suggest an unguided sit.` Plus: the card is already shown, don't
re-list it; say one line and, if a cut component fits better, propose it.

## Listens

Table `listens`: `id`, `session_id` (nullable FK to `morning_sessions`), `recording_id`,
`started_at` (timestamptz). Alembic migration `add_listens`.

`POST /api/morning/sessions/{id}/listens` body `{recording_id, message_id?}` → inserts a row
and records `played` on the options message the user pressed play on (`data.played =
recording_id`), so the card can show it and the prompt can say it. Without a `message_id` it
falls back to the session's latest options message. Response `{"ok": true}`.

## Tool

```
find_guided_meditations(inquiry: str, max_minutes?: int)
```

Description for the model: search Jason's guided-meditation recordings (Rigdzin, Jhourney,
Burbea) for ones that fit what he said this morning. Phrase the inquiry as the need, not a
title: "settling a scattered anxious mind", "grief that wants holding". Recently heard ones
are excluded automatically. Use it in the third beat of the check-in when a guided sit might
serve better than silence, or when he asks for one. At most once per turn: a second call in
the same turn searches nothing, persists nothing, and comes back `Already searched this turn;
work with the options shown.`

Persisted tool message: `role=tool`, `tool_label="Guided meditation options"`,
`content=<inquiry>`, `data={"choices": [...], "played": null}`. Replayed to the model as
`[Guided meditation options: <inquiry> → <name>; <name> — played: <name>]`.

Pending chip label: `Searching guided meditations…`.

## Card (in `morning.html`)

Rendered like the routine proposal, below the label `Guided meditation options`:

- Zero choices: the line *Nothing fits this morning.*
- Otherwise one row per choice: **name** · `N min` · collection, the *why* clause beneath in
  the muted style, and a `▶ play` chip at the right. If `data.played` matches, the chip reads
  `playing` while it is the player's current track, else `played`.
- A choice with `component_slugs` shows nothing extra; the model handles that in prose.

## Player

One docked widget at the bottom of the chat column, above the composer, hidden until a track
is loaded. It is not the runner: no bells, no countdown, no program logging.

- Layout, one row: `▶`/`❚❚` button · name (ellipsized) · `−15` · `+15` · a scrubber that
  spans the remaining width · `elapsed / total` · `×` to unload.
- Backed by a single `<audio preload="metadata">` element, `src = /media/recordings/<id>.mp3`.
  Loading a track while another plays replaces it.
- Play POSTs the listen once per load (not on every resume).
- `navigator.mediaSession` metadata carries the name and wires play/pause/seek so the lock
  screen controls work.
- Keyboard: none (the runner owns space/arrows when open). The runner and the player never
  play together: opening the runner pauses the player.
- Persists across `renderChat`; survives session switches (a track keeps playing until
  unloaded).
- Daylight DC-1 first (1280×1080, grayscale): high-contrast strokes, no color-only state.
  Under 600px the time label drops and the scrubber takes the row.

## Verification

- `tests/test_recordings.py`: transcript parsing on a fixture (headers, folder-less Jhourney
  source, guided filter per collection), snippet extraction, the recent set from listens and
  program snapshots, selector output parsing (unknown ids dropped, malformed or truncated →
  empty), and the tool loop refusing a second search in one turn.
- `pytest tests -q` green.
- Live: on the tailnet dashboard, a check-in that asks for a guided sit shows the card with
  one to four choices; play starts audio in the docked player, a `listens` row appears, and
  the same inquiry a second time no longer offers the played recording.
