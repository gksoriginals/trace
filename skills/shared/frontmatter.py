"""YAML-ish frontmatter helpers for markdown memory notes (ADR-0007).

Uses a minimal subset (key: value, nested via dotted keys or JSON values)
so skills do not require PyYAML. Complex nested objects are stored as JSON
on a single line after the key.
"""

from __future__ import annotations

import json
import re
from typing import Any


def dump_frontmatter(data: dict[str, Any], body: str = "") -> str:
    lines = ["---"]
    for key, value in data.items():
        lines.append(f"{key}: {_format_value(value)}")
    lines.append("---")
    body = body or ""
    if body and not body.startswith("\n"):
        return "\n".join(lines) + "\n\n" + body.rstrip() + "\n"
    return "\n".join(lines) + "\n" + body


def load_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    text = text.lstrip("\ufeff")
    if not text.startswith("---"):
        return {}, text
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n?(.*)$", text, re.DOTALL)
    if not match:
        return {}, text
    meta: dict[str, Any] = {}
    for line in match.group(1).splitlines():
        if not line.strip() or line.strip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, raw = line.split(":", 1)
        meta[key.strip()] = _parse_value(raw.strip())
    return meta, match.group(2)


def event_to_frontmatter(event: dict) -> tuple[dict[str, Any], str]:
    """Flatten a v1 memory event into frontmatter + body (why as prose)."""
    what = event.get("what") or {}
    agent = event.get("agent") or {}
    project = event.get("project") or {}
    created = event.get("created") or {}
    attribution = event.get("attribution")
    meta: dict[str, Any] = {
        "schema_version": event.get("schema_version", 1),
        "event_id": event.get("event_id"),
        "event_type": event.get("event_type"),
        "status": event.get("status") or "active",
        "claim": event.get("claim"),
        "what.id": what.get("id"),
        "what.kind": what.get("kind"),
        "what.location": what.get("location"),
        "what.bytes": what.get("bytes"),
        "what.completeness": what.get("completeness"),
        "agent.harness": agent.get("harness"),
        "agent.session_id": agent.get("session_id"),
        "project.id": project.get("id"),
        "project.consumers": project.get("consumers") or [],
        "created.at": created.get("at"),
        "created.source": created.get("source"),
        "can_go_when": event.get("can_go_when"),
        "evidence_ids": event.get("evidence_ids") or [],
        "correction_of": event.get("correction_of"),
    }
    if attribution:
        meta["attribution"] = attribution
    body = (event.get("why") or "").strip() + "\n"
    return meta, body


def frontmatter_to_event(meta: dict[str, Any], body: str) -> dict:
    """Rebuild a v1 memory event dict from frontmatter + body."""
    event = {
        "schema_version": int(meta.get("schema_version") or 1),
        "event_id": meta.get("event_id"),
        "event_type": meta.get("event_type"),
        "status": meta.get("status") or "active",
        "what": {
            "id": meta.get("what.id"),
            "kind": meta.get("what.kind"),
            "location": meta.get("what.location"),
            "bytes": meta.get("what.bytes"),
            "completeness": meta.get("what.completeness"),
        },
        "why": body.strip(),
        "claim": meta.get("claim"),
        "agent": {
            "harness": meta.get("agent.harness"),
            "session_id": meta.get("agent.session_id"),
        },
        "project": {
            "id": meta.get("project.id"),
            "consumers": meta.get("project.consumers") or [],
        },
        "created": {
            "at": meta.get("created.at"),
            "source": meta.get("created.source"),
        },
        "can_go_when": meta.get("can_go_when"),
        "evidence_ids": meta.get("evidence_ids") or [],
        "correction_of": meta.get("correction_of"),
    }
    if meta.get("attribution"):
        event["attribution"] = meta["attribution"]
    return event


def _format_value(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        if "\n" in value or value[:1] in "[{":
            return json.dumps(value, ensure_ascii=False)
        return value
    return json.dumps(value, ensure_ascii=False)


def _parse_value(raw: str) -> Any:
    if raw == "null" or raw == "~" or raw == "":
        return None
    if raw == "true":
        return True
    if raw == "false":
        return False
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if raw.startswith("{") or raw.startswith("[") or raw.startswith('"'):
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw
    return raw
