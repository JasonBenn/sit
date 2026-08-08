"""Read and write entries in the Obsidian wake-up log.

The file is newest-first: a one-line italic description, then `### [[date]] title`
entries. Obsidian's own sync propagates changes; we only touch the local file.
"""
import os
import re
from datetime import date, datetime

WAKE_UP_LOG = os.getenv("WAKE_UP_LOG", os.path.expanduser("~/notes/Logs/Wake up.md"))

HEADING_RE = re.compile(r"^### \[\[(?P<date>[^\]]+)\]\]\s*(?P<title>.*)$")


def _read_lines() -> list[str]:
    with open(WAKE_UP_LOG, encoding="utf-8") as f:
        return f.read().splitlines()


def _write_lines(lines: list[str]) -> None:
    with open(WAKE_UP_LOG, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def _format_date(raw: str) -> str:
    try:
        return datetime.strptime(raw, "%Y-%m-%d").strftime("%B %-d, %Y")
    except ValueError:
        return raw  # e.g. [[2026-W07]]


def read_entries(limit: int | None = None) -> list[dict]:
    entries = []
    current = None
    for line in _read_lines():
        m = HEADING_RE.match(line)
        if m:
            if current:
                entries.append(current)
                if limit and len(entries) >= limit:
                    return entries
            current = {
                "date": _format_date(m.group("date")),
                "raw_date": m.group("date"),
                "title": m.group("title"),
                "body": "",
            }
        elif current is not None:
            current["body"] += line + "\n"
    if current and not (limit and len(entries) >= limit):
        entries.append(current)
    return entries


def make_heading(title: str, today: date) -> str:
    return f"### [[{today.isoformat()}]] {title}"


def write_entry(heading: str, body: str) -> None:
    """Insert a new entry at the top, right after the file's description line."""
    lines = _read_lines()
    entry = [heading] + body.strip().splitlines()
    lines[1:1] = entry
    _write_lines(lines)


def read_entry(heading: str) -> str:
    """Return the body of the entry with this exact heading line."""
    lines = _read_lines()
    start = lines.index(heading)
    end = start + 1
    while end < len(lines) and not lines[end].startswith("### "):
        end += 1
    return "\n".join(lines[start + 1:end])


def update_entry(old_heading: str, new_heading: str, body: str) -> None:
    """Replace the block starting at old_heading (through the next heading) in place."""
    lines = _read_lines()
    start = lines.index(old_heading)
    end = start + 1
    while end < len(lines) and not lines[end].startswith("### "):
        end += 1
    lines[start:end] = [new_heading] + body.strip().splitlines()
    _write_lines(lines)
