"""Materialize a fixture into a temp project the driver can touch."""

from __future__ import annotations

from pathlib import Path


def materialize(fixture: dict, workspace: Path) -> None:
    workspace.mkdir(parents=True, exist_ok=True)
    for rel, content in (fixture.get("files") or {}).items():
        path = workspace / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
