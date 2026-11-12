"""Append-only per-project memory log."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from .io import append_line
from .redact import redact_text
from .schemas import SchemaError, validate_memory_event


def default_memory_log(project_root: Path | str) -> Path:
    """First-guess product path: `<project-root>/.trace/memory.jsonl`."""
    return Path(project_root).expanduser().resolve() / ".trace" / "memory.jsonl"


def validate_event(event: dict, *, redact: bool = True) -> dict:
    """Validate and optionally redact a memory event before writing."""
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
    """Append validated events to a JSONL log. Returns the written events."""
    path = Path(log_path).expanduser()
    written: list[dict] = []
    for raw in events:
        event = validate_event(raw, redact=redact)
        append_line(path, json.dumps(event, ensure_ascii=False, separators=(",", ":")))
        written.append(event)
    if not written:
        raise SchemaError("at least one memory event is required")
    return written


def read_events(log_path: Path | str) -> list[dict]:
    path = Path(log_path).expanduser()
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
