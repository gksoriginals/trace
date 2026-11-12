"""Durable Decide-later queue (version 1). Dedupes by id; repeats update evidence."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .io import atomic_write_text
from .schemas import SchemaError, require_list, require_mapping, require_nonempty_str

QUEUE_STATUSES = frozenset({"open", "planned", "deferred", "kept", "resolved", "stale"})


def default_queue_path(project_root: Path | str) -> Path:
    return Path(project_root).expanduser().resolve() / ".trace" / "decide-later.json"


def validate_queue_item(item: dict) -> dict:
    item = require_mapping(item, "queue item")
    if item.get("schema_version") != 1:
        raise SchemaError("queue schema_version must be 1")
    for key in (
        "id", "project_id", "agent", "session_id", "artifact_id", "action",
        "why_doubtful", "completeness", "would_resolve", "first_observed", "last_observed",
    ):
        require_nonempty_str(item.get(key), key)
    if item.get("status") not in QUEUE_STATUSES:
        raise SchemaError(f"status must be one of {sorted(QUEUE_STATUSES)}")
    evidence = require_list(item.get("evidence_ids"), "evidence_ids")
    if not evidence:
        raise SchemaError("evidence_ids must be non-empty")
    if "bytes" not in item:
        raise SchemaError("bytes is required (null when unknown)")
    if item["bytes"] is not None and not isinstance(item["bytes"], int):
        raise SchemaError("bytes must be an int or null")
    return item


def load_queue(path: Path | str) -> list[dict]:
    path = Path(path).expanduser()
    if not path.is_file():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        items = data.get("items") or []
    else:
        items = data
    require_list(items, "items")
    return [validate_queue_item(item) for item in items]


def upsert_items(path: Path | str, items: list[dict]) -> list[dict]:
    """Merge items by id. A repeat updates evidence and last_observed; no duplicate ids."""
    path = Path(path).expanduser()
    existing = {item["id"]: item for item in load_queue(path)}
    for raw in items:
        item = validate_queue_item(dict(raw))
        prior = existing.get(item["id"])
        if prior is None:
            existing[item["id"]] = item
            continue
        merged = dict(prior)
        merged["last_observed"] = item["last_observed"]
        merged["why_doubtful"] = item["why_doubtful"]
        merged["would_resolve"] = item["would_resolve"]
        merged["status"] = item.get("status") or prior.get("status")
        merged["bytes"] = item["bytes"] if "bytes" in item else prior.get("bytes")
        merged["completeness"] = item.get("completeness") or prior.get("completeness")
        evidence = list(dict.fromkeys([*(prior.get("evidence_ids") or []), *(item.get("evidence_ids") or [])]))
        merged["evidence_ids"] = evidence
        if item.get("first_observed"):
            merged["first_observed"] = prior.get("first_observed") or item["first_observed"]
        existing[item["id"]] = validate_queue_item(merged)
    ordered = list(existing.values())
    payload = {"items": ordered}
    atomic_write_text(path, json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    return ordered


def write_queue(path: Path | str, items: list[dict]) -> list[dict]:
    """Replace the queue file with the given items (still validated and unique)."""
    validated = [validate_queue_item(dict(item)) for item in items]
    ids = [item["id"] for item in validated]
    if len(ids) != len(set(ids)):
        raise SchemaError("queue ids must be unique")
    path = Path(path).expanduser()
    atomic_write_text(path, json.dumps({"items": validated}, indent=2, ensure_ascii=False) + "\n")
    return validated
