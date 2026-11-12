"""Per-project memory: markdown notes (ADR-0007) plus JSONL export for evals."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Iterable

from .frontmatter import dump_frontmatter, event_to_frontmatter, frontmatter_to_event, load_frontmatter
from .io import append_line, atomic_write_text
from .redact import redact_text
from .schemas import SchemaError, validate_memory_event


def default_memory_dir(project_root: Path | str) -> Path:
    return Path(project_root).expanduser().resolve() / ".trace" / "memory"


def default_memory_log(project_root: Path | str) -> Path:
    """Legacy path kept for evals that still write JSONL under trace-out/."""
    return Path(project_root).expanduser().resolve() / ".trace" / "memory.jsonl"


def validate_event(event: dict, *, redact: bool = True) -> dict:
    payload = dict(event)
    if redact and isinstance(payload.get("why"), str):
        payload["why"] = redact_text(payload["why"])
    return validate_memory_event(payload)


def append_events(
    log_path: Path | str,
    events: Iterable[dict],
    *,
    redact: bool = True,
) -> list[dict]:
    """Append validated events as JSONL (eval / compatibility path)."""
    path = Path(log_path).expanduser()
    written: list[dict] = []
    for raw in events:
        event = validate_event(raw, redact=redact)
        append_line(path, json.dumps(event, ensure_ascii=False, separators=(",", ":")))
        written.append(event)
    if not written:
        raise SchemaError("at least one memory event is required")
    return written


def write_events_markdown(
    memory_dir: Path | str,
    events: Iterable[dict],
    *,
    redact: bool = True,
) -> list[dict]:
    """Write one markdown note per event under memory_dir (product path)."""
    directory = Path(memory_dir).expanduser()
    directory.mkdir(parents=True, exist_ok=True)
    written: list[dict] = []
    for raw in events:
        event = validate_event(raw, redact=redact)
        if "status" not in event:
            event = {**event, "status": "active"}
        meta, body = event_to_frontmatter(event)
        safe_id = re.sub(r"[^a-zA-Z0-9._-]+", "_", str(event["event_id"]))
        path = directory / f"{safe_id}.md"
        atomic_write_text(path, dump_frontmatter(meta, body))
        written.append(event)
    if not written:
        raise SchemaError("at least one memory event is required")
    return written


def read_events(log_path: Path | str) -> list[dict]:
    """Read JSONL log or a markdown memory directory."""
    path = Path(log_path).expanduser()
    if path.is_dir():
        return read_events_markdown(path)
    if not path.is_file():
        return []
    events: list[dict] = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise SchemaError(f"torn or invalid JSONL at {path}:{line_no}") from exc
    return events


def read_events_markdown(memory_dir: Path | str) -> list[dict]:
    directory = Path(memory_dir).expanduser()
    if not directory.is_dir():
        return []
    events: list[dict] = []
    for path in sorted(directory.glob("*.md")):
        meta, body = load_frontmatter(path.read_text(encoding="utf-8"))
        if not meta.get("event_id"):
            continue
        events.append(frontmatter_to_event(meta, body))
    return events


def set_event_status(memory_dir: Path | str, event_id: str, status: str) -> bool:
    directory = Path(memory_dir).expanduser()
    safe_id = re.sub(r"[^a-zA-Z0-9._-]+", "_", event_id)
    path = directory / f"{safe_id}.md"
    if not path.is_file():
        return False
    meta, body = load_frontmatter(path.read_text(encoding="utf-8"))
    meta["status"] = status
    atomic_write_text(path, dump_frontmatter(meta, body))
    return True
