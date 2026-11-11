"""Conservative path guards shared by skills. Phase 1 records only; later phases Trash."""

from __future__ import annotations

from pathlib import Path

# Directional never-delete prefixes. Product expands this with user never-touch list.
NEVER_DELETE_PREFIXES = (
    "/System",
    "/usr",
    "/bin",
    "/sbin",
    "/Library",
    "/private/var/db",
)


def is_never_delete(path: Path | str, never_touch: list[str] | None = None) -> bool:
    resolved = str(Path(path).expanduser())
    for prefix in NEVER_DELETE_PREFIXES:
        if resolved == prefix or resolved.startswith(prefix + "/"):
            return True
    for item in never_touch or []:
        item_path = str(Path(item).expanduser())
        if resolved == item_path or resolved.startswith(item_path.rstrip("/") + "/"):
            return True
    return False
