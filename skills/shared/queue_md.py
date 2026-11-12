"""Decide-later as markdown (product) with JSON helper for evals."""

from __future__ import annotations

import json
from pathlib import Path

from .frontmatter import dump_frontmatter, load_frontmatter
from .io import atomic_write_text
from .queue import validate_queue_item, write_queue


def default_queue_md_path(project_root: Path | str) -> Path:
    return Path(project_root).expanduser().resolve() / ".trace" / "decide-later.md"


def write_queue_markdown(path: Path | str, items: list[dict]) -> list[dict]:
    validated = [validate_queue_item(dict(item)) for item in items]
    path = Path(path).expanduser()
    meta = {"schema_version": 1, "items": validated}
    body_lines = ["# Decide later", ""]
    for item in validated:
        body_lines.append(f"## {item['id']} ({item['status']})")
        body_lines.append(f"- action: {item['action']}")
        body_lines.append(f"- why: {item['why_doubtful']}")
        body_lines.append(f"- would resolve: {item['would_resolve']}")
        body_lines.append("")
    atomic_write_text(path, dump_frontmatter(meta, "\n".join(body_lines)))
    return validated


def load_queue_markdown(path: Path | str) -> list[dict]:
    path = Path(path).expanduser()
    if not path.is_file():
        return []
    if path.suffix == ".json":
        from .queue import load_queue
        return load_queue(path)
    meta, _body = load_frontmatter(path.read_text(encoding="utf-8"))
    items = meta.get("items") or []
    return [validate_queue_item(dict(item)) for item in items]


def write_both(project_root: Path | str, items: list[dict]) -> list[dict]:
    """Write md (product) and json next to it for tooling that still expects json."""
    root = Path(project_root).expanduser().resolve() / ".trace"
    validated = write_queue_markdown(root / "decide-later.md", items)
    write_queue(root / "decide-later.json", validated)
    return validated
