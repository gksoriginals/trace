"""Skill-maintained project index (`~/.trace/index.md` by default, ADR-0007)."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .frontmatter import dump_frontmatter, load_frontmatter
from .io import atomic_write_text
from .schemas import SchemaError, validate_index


def default_index_path(trace_home: Path | str | None = None) -> Path:
    if trace_home is not None:
        root = Path(trace_home).expanduser()
    else:
        env = os.environ.get("TRACE_HOME")
        root = Path(env).expanduser() if env else Path.home() / ".trace"
    # Prefer md; fall back to legacy json if present and md missing
    md = root / "index.md"
    legacy = root / "index.json"
    if md.is_file() or not legacy.is_file():
        return md
    return legacy


def load_index(path: Path | str) -> dict:
    path = Path(path).expanduser()
    if not path.is_file():
        return {"schema_version": 1, "projects": []}
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".json" or text.lstrip().startswith("{"):
        document = json.loads(text)
    else:
        meta, body = load_frontmatter(text)
        projects_raw = meta.get("projects")
        if projects_raw is None:
            # body may contain a JSON projects block
            body = body.strip()
            if body.startswith("```"):
                body = body.strip("`").removeprefix("json").strip()
            projects_raw = json.loads(body) if body else []
        document = {
            "schema_version": int(meta.get("schema_version") or 1),
            "projects": projects_raw if isinstance(projects_raw, list) else [],
        }
    # Normalize memory_dir onto memory_log for validate_index
    for project in document.get("projects") or []:
        if project.get("memory_dir") and not project.get("memory_log"):
            project["memory_log"] = project["memory_dir"]
    return validate_index(document)


def upsert_project(
    index_path: Path | str,
    *,
    project_id: str,
    memory_log: Path | str | None = None,
    memory_dir: Path | str | None = None,
    display_name: str | None = None,
    roots: list[str] | None = None,
    opt_out: bool = False,
    updated_at: str | None = None,
) -> dict:
    if not project_id or not str(project_id).strip():
        raise SchemaError("project_id must be a non-empty string")
    mem_path = memory_dir or memory_log
    if mem_path is None:
        raise SchemaError("memory_dir or memory_log is required")
    memory_path = str(Path(mem_path).expanduser().resolve())
    path = Path(index_path).expanduser()
    # Always write markdown index going forward
    if path.suffix == ".json":
        path = path.with_suffix(".md")
    document = load_index(path if path.is_file() else index_path)
    projects: list[dict[str, Any]] = list(document.get("projects") or [])
    row = {
        "id": project_id,
        "display_name": display_name or project_id,
        "roots": list(roots or []),
        "memory_dir": memory_path,
        "memory_log": memory_path,  # compat for validators/readers
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
    meta = {"schema_version": 1, "projects": projects}
    body = (
        "Trace project index. Skills maintain this file. "
        "The app reads it; Home does not call a model to open.\n\n"
        "```json\n"
        + json.dumps(projects, indent=2, ensure_ascii=False)
        + "\n```\n"
    )
    atomic_write_text(path, dump_frontmatter(meta, body))
    return document
