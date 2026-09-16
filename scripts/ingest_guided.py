#!/usr/bin/env python3
"""Ingest guided-meditation recordings into the Sit practice library.

1. Read scripts/guided_manifest.json — one entry per component (slug, name, summary,
   source audio, and either one optional `clip` or a `steps` list of jumpable phases).
2. Resolve each source: absolute path as given, otherwise relative to the Drive mirror
   of Meditations/ on nose (rclone, hourly). Missing sources are reported and skipped, not fatal.
3. Cut with ffmpeg (-ss/-to, re-encoded to 128k mono mp3) into <media-dir>/<slug>.mp3, or
   <slug>-01.mp3, <slug>-02.mp3, … for a multi-step entry, so every phase is a standalone file.
4. Measure each cut file's real duration with ffprobe.
5. Upsert: GET /api/morning/components, skip slugs that exist, else POST a `guided`
   component whose steps are those phases in order, each pointing at /media/guided/<file>.mp3.
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, "scripts", "guided_manifest.json")
MEDITATIONS = "/opt/sit-media/drive/Meditations"


def resolve_source(source, meditations):
    return source if os.path.isabs(source) else os.path.join(meditations, source)


def readable(path):
    """A source missing from the mirror is a skip, not a crash."""
    try:
        with open(path, "rb") as f:
            f.read(1)
        return True, ""
    except OSError as e:
        return False, e.strerror or str(e)


def cut(src, dest, clip):
    """`clip` may omit `end`, in which case the cut runs to the end of the source."""
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    if clip:
        cmd += ["-ss", clip["start"]]
        if clip.get("end"):
            cmd += ["-to", clip["end"]]
    cmd += ["-i", src, "-vn", "-ac", "1", "-b:a", "128k", "-map_metadata", "-1", dest]
    subprocess.run(cmd, check=True)


def phases(entry):
    """One (output basename, clip) per audio file this entry produces. A single-clip
    entry yields <slug>; a multi-step entry yields <slug>-01, <slug>-02, …"""
    steps = entry.get("steps")
    if not steps:
        return [(entry["slug"], entry.get("clip"))]
    return [(f"{entry['slug']}-{i:02d}", s["clip"]) for i, s in enumerate(steps, 1)]


def measure(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", path],
        check=True, capture_output=True, text=True,
    )
    return round(float(out.stdout.strip()))


def existing_slugs(api):
    with urllib.request.urlopen(f"{api}/api/morning/components", timeout=30) as r:
        return {c["slug"] for c in json.load(r)["components"]}


def component_steps(entry, durations):
    """durations: the measured seconds of each cut file, in phase order."""
    meta = entry.get("steps") or [{"title": entry["name"]}]
    steps = []
    for (base, _), phase, duration_s in zip(phases(entry), meta, durations):
        step = {
            "title": phase["title"],
            "media": {"type": "audio", "src": f"/media/guided/{base}.mp3"},
            "duration_s": duration_s,
            "bell": "soft",
        }
        if phase.get("text"):
            step["text"] = phase["text"]
        steps.append(step)
    steps[-1]["bell"] = "long"
    return steps


def post_component(api, entry, durations):
    body = json.dumps({
        "kind": "guided",
        "slug": entry["slug"],
        "name": entry["name"],
        "summary": entry["summary"],
        "steps": component_steps(entry, durations),
    }).encode()
    req = urllib.request.Request(
        f"{api}/api/morning/components", data=body,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["component"]


def main():
    p = argparse.ArgumentParser(description="Ingest guided meditations into the Sit practice library.")
    p.add_argument("--manifest", default=MANIFEST, help="manifest JSON to ingest")
    p.add_argument("--only", help="comma-separated slugs to process")
    p.add_argument("--api", default="http://localhost:8005")
    p.add_argument("--media-dir", default="/opt/sit-media/guided", help="staging dir for cut audio")
    p.add_argument("--meditations", default=MEDITATIONS, help="dir that relative sources resolve against")
    p.add_argument("--dry-run", action="store_true", help="resolve sources and report readability only")
    args = p.parse_args()
    sys.stdout.reconfigure(line_buffering=True)  # keep our lines interleaved with ffmpeg output

    entries = json.load(open(args.manifest))
    if args.only:
        wanted = [s.strip() for s in args.only.split(",")]
        unknown = [s for s in wanted if s not in {e["slug"] for e in entries}]
        if unknown:
            sys.exit(f"unknown slugs: {', '.join(unknown)}")
        entries = [e for e in entries if e["slug"] in wanted]

    if args.dry_run:
        print(f"{'slug':<28} {'readable':<9} source")
        for e in entries:
            src = resolve_source(e["source"], args.meditations)
            ok, why = readable(src)
            print(f"{e['slug']:<28} {('yes' if ok else 'NO'):<9} {src}" + ("" if ok else f"   [{why}]"))
            meta = e.get("steps") or [{"title": e["name"]}]
            for (base, clip), phase in zip(phases(e), meta):
                span = "whole file" if not clip else f"{clip['start']}–{clip.get('end', 'end')}"
                print(f"{'':<28} {'':<9}   {base}.mp3  {span:<21} {phase['title']}")
        return

    os.makedirs(args.media_dir, exist_ok=True)
    slugs = existing_slugs(args.api)

    for e in entries:
        slug = e["slug"]
        src = resolve_source(e["source"], args.meditations)
        ok, why = readable(src)
        if not ok:
            print(f"skip {slug}: source unreadable ({why}): {src}")
            continue
        durations = []
        for base, clip in phases(e):
            dest = os.path.join(args.media_dir, f"{base}.mp3")
            cut(src, dest, clip)
            durations.append(measure(dest))
            print(f"cut  {base}.mp3: {durations[-1]}s -> {dest}")
        if "duration_s" in e:
            print(f"     total {sum(durations)}s (manifest said {e['duration_s']}s)")
        if slug in slugs:
            print(f"     component {slug} already exists, not posting")
            continue
        component = post_component(args.api, e, durations)
        print(f"     created component {component['slug']} ({component['id']}), {len(durations)} step(s)")


main()
