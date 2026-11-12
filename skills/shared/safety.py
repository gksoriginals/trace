"""Conservative path guards shared by skills and the action boundary."""

from __future__ import annotations

import hashlib
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

NEVER_DELETE_HOME_SUFFIXES = (
    "/Documents",
    "/Pictures",
    "/Movies",
    "/Music",
    "/Library/Mail",
    "/.ssh",
    "/.gnupg",
    "/.aws",
    "/.config/gcloud",
)


def is_never_delete(path: Path | str, never_touch: list[str] | None = None) -> bool:
    resolved = str(Path(path).expanduser().resolve()) if Path(path).exists() else str(Path(path).expanduser())
    for prefix in NEVER_DELETE_PREFIXES:
        if resolved == prefix or resolved.startswith(prefix + "/"):
            return True
    home = str(Path.home())
    for suffix in NEVER_DELETE_HOME_SUFFIXES:
        protected = home + suffix
        if resolved == protected or resolved.startswith(protected + "/"):
            return True
    name = Path(resolved).name
    if name in {".env", ".env.local", "id_rsa", "id_ed25519", "credentials", "credentials.json"}:
        return True
    for item in never_touch or []:
        item_path = str(Path(item).expanduser())
        if resolved == item_path or resolved.startswith(item_path.rstrip("/") + "/"):
            return True
    return False


def fingerprint(path: Path | str) -> str:
    """Stable identity for confirm-time re-check: type, size, mtime_ns, content hash for files."""
    p = Path(path)
    if not p.exists():
        return "missing"
    stat = p.stat()
    if p.is_dir():
        return f"dir:{stat.st_ino}:{stat.st_mtime_ns}:{stat.st_nlink}"
    digest = hashlib.sha256()
    with p.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return f"file:{stat.st_ino}:{stat.st_size}:{stat.st_mtime_ns}:{digest.hexdigest()}"


def fingerprint_matches(path: Path | str, expected: str) -> bool:
    return fingerprint(path) == expected
