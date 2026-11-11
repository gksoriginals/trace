"""Eval/dogfood Trash boundary: move only exact consented paths; never permanent delete."""

from __future__ import annotations

import shutil
from pathlib import Path

from .safety import is_never_delete


class TrashError(ValueError):
    pass


def move_to_trash(
    workspace: Path,
    relative_path: str,
    *,
    consent: list[str],
    protected: list[str] | None = None,
    trash_root: Path | None = None,
) -> Path:
    """Move one relative path into trash_root if it is exactly consented and not protected."""
    if relative_path not in consent:
        raise TrashError(f"not consented: {relative_path}")
    if relative_path in (protected or []):
        raise TrashError(f"protected: {relative_path}")
    source = workspace / relative_path
    if not source.exists():
        raise TrashError(f"missing: {relative_path}")
    if is_never_delete(source):
        raise TrashError(f"never-delete: {relative_path}")
    dest_root = trash_root or (workspace / "trace-out" / "trash")
    dest = dest_root / relative_path
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        raise TrashError(f"trash destination exists: {relative_path}")
    shutil.move(str(source), str(dest))
    return dest
