"""Skill-maintained project index (`~/.trace/index.json` by default)."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .io import atomic_write_text
from .schemas import SchemaError, validate_index


def default_index_path(trace_home: Path | str | None = None) -> Path:
    """Directional product path: `~/.trace/index.json`, overridable via TRACE_HOME."""
    if trace_home is not None:
        root = Path(trace_home).expanduser()
    else:
        env = os.environ.get("TRACE_HOME")
        root = Path(env).expanduser() if env else Path.home() / ".trace"
    return root / "index.json"


def load_index(path: Path | str) -> dict:
    path = Path(path).expanduser()
    if not path.is_file():
        return {"schema_version": 1, "projects": []}
    document = json.loads(path.read_text(encoding="utf-8"))
    return validate_index(document)


def upsert_project(
    index_path: Path | str,
    *,
    project_id: str,
    memory_log: Path | str,
    display_name: str | None = None,
    roots: list[str] | None = None,
    opt_out: bool = False,
    updated_at: str | None = None,
) -> dict:
    """Replace or insert one project row, then atomically rewrite the index."""
    if not project_id or not str(project_id).strip():
        raise SchemaError("project_id must be a non-empty string")
    memory_log_path = str(Path(memory_log).expanduser().resolve())
    document = load_index(index_path)
    projects: list[dict[str, Any]] = list(document.get("projects") or [])
    row = {
        "id": project_id,
        "display_name": display_name or project_id,
        "roots": list(roots or []),
        "memory_log": memory_log_path,
        "opt_out": bool(opt_out),
        "updated_at": updated_at or datetime.now(timezone.utc).isoformat(),
    }
    replaced = False
    for i, existing in enumerate(projects):
        if existing.get("id") == project_id:
            merged = dict(existing)
            merged.update(row)
            if roots is None and "roots" in existing:
                merged["roots"] = existing["roots"]
            projects[i] = merged
            replaced = True
            break
    if not replaced:
        projects.append(row)
    document = {"schema_version": 1, "projects": projects}
    validate_index(document)
    atomic_write_text(Path(index_path).expanduser(), json.dumps(document, indent=2, ensure_ascii=False) + "\n")
    return document
