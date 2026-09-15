#!/usr/bin/env python3
"""Ingest guided-meditation recordings into the Sit practice library.

1. Read scripts/guided_manifest.json — one entry per component (slug, name, summary,
   source audio, optional clip range).
2. Resolve each source: absolute path as given, otherwise relative to the clipper's
   Meditations/ dir. Unreadable sources are reported and skipped, not fatal.
3. Cut with ffmpeg (-ss/-to, re-encoded to 128k mono mp3) into <media-dir>/<slug>.mp3,
   so every output is a clean file with an exact duration; whole files go through ffmpeg too.
4. Measure the real duration with ffprobe.
5. Upsert: GET /api/morning/components, skip slugs that exist, else POST a `guided`
   component with one audio step pointing at /media/guided/<slug>.mp3.
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
MEDITATIONS = "/Users/jasonbenn/code/meditation-clipper/Meditations"


def resolve_source(source):
    return source if os.path.isabs(source) else os.path.join(MEDITATIONS, source)


def readable(path):
    """Google Drive paths raise PermissionError under macOS sandboxing; that is a
    skip, not a crash, so this is the one place we catch."""
    try:
        with open(path, "rb") as f:
            f.read(1)
        return True, ""
    except OSError as e:
        return False, e.strerror or str(e)


def cut(src, dest, clip):
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src]
    if clip:
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-ss", clip["start"], "-to", clip["end"], "-i", src]
    cmd += ["-vn", "-ac", "1", "-b:a", "128k", "-map_metadata", "-1", dest]
    subprocess.run(cmd, check=True)


def measure(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", path],
        check=True, capture_output=True, text=True,
    )
    return round(float(out.stdout.strip()))


def existing_slugs(api):
    with urllib.request.urlopen(f"{api}/api/morning/components", timeout=30) as r:
        return {c["slug"] for c in json.load(r)["components"]}


def post_component(api, entry, duration_s):
    body = json.dumps({
        "kind": "guided",
        "slug": entry["slug"],
        "name": entry["name"],
        "summary": entry["summary"],
        "steps": [{
            "title": entry["name"],
            "media": {"type": "audio", "src": f"/media/guided/{entry['slug']}.mp3"},
            "duration_s": duration_s,
            "bell": "long",
        }],
    }).encode()
    req = urllib.request.Request(
        f"{api}/api/morning/components", data=body,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["component"]


def main():
    p = argparse.ArgumentParser(description="Ingest guided meditations into the Sit practice library.")
    p.add_argument("--only", help="comma-separated slugs to process")
    p.add_argument("--api", default="http://localhost:8005")
    p.add_argument("--media-dir", default="/opt/sit-media/guided", help="staging dir for cut audio")
    p.add_argument("--push", help="rsync target for the staging dir, e.g. nose:/opt/sit-media/guided")
    p.add_argument("--dry-run", action="store_true", help="resolve sources and report readability only")
    args = p.parse_args()
    sys.stdout.reconfigure(line_buffering=True)  # keep our lines interleaved with ffmpeg/rsync output

    entries = json.load(open(MANIFEST))
    if args.only:
        wanted = [s.strip() for s in args.only.split(",")]
        unknown = [s for s in wanted if s not in {e["slug"] for e in entries}]
        if unknown:
            sys.exit(f"unknown slugs: {', '.join(unknown)}")
        entries = [e for e in entries if e["slug"] in wanted]

    if args.dry_run:
        print(f"{'slug':<28} {'readable':<9} source")
        for e in entries:
            src = resolve_source(e["source"])
            ok, why = readable(src)
            print(f"{e['slug']:<28} {('yes' if ok else 'NO'):<9} {src}" + ("" if ok else f"   [{why}]"))
        return

    os.makedirs(args.media_dir, exist_ok=True)
    slugs = existing_slugs(args.api)
    cut_any = False

    for e in entries:
        slug = e["slug"]
        src = resolve_source(e["source"])
        ok, why = readable(src)
        if not ok:
            print(f"skip {slug}: source unreadable ({why}): {src}")
            continue
        dest = os.path.join(args.media_dir, f"{slug}.mp3")
        cut(src, dest, e.get("clip"))
        cut_any = True
        duration_s = measure(dest)
        print(f"cut  {slug}: {duration_s}s (manifest said {e['duration_s']}s) -> {dest}")
        if slug in slugs:
            print(f"     component {slug} already exists, not posting")
            continue
        component = post_component(args.api, e, duration_s)
        print(f"     created component {component['slug']} ({component['id']})")

    if args.push and cut_any:
        subprocess.run(["rsync", "-av", args.media_dir.rstrip("/") + "/", args.push.rstrip("/") + "/"], check=True)
        print(f"pushed {args.media_dir} -> {args.push}")


main()
