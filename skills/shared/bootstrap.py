"""Put the shared package on sys.path for repo and installed layouts."""

from __future__ import annotations

import sys
from pathlib import Path


def ensure_shared(start: Path | None = None) -> Path:
    """
    Resolve shared code for:
    - repo:      skills/shared
    - install:   ~/.agents/skills/trace-shared  (files of the shared package)
    """
    start = (start or Path(__file__)).resolve()
    candidates = []
    # When imported from skills/shared/bootstrap.py
    if start.name == "bootstrap.py":
        candidates.append(start.parent.parent)  # skills/
    # Scripts live at skills/<skill>/scripts/*.py
    for parent in Path(__file__).resolve().parents:
        candidates.append(parent)
        candidates.append(parent / "skills")
        candidates.append(parent / "trace-shared")

    seen: set[Path] = set()
    for cand in candidates:
        cand = cand.resolve()
        if cand in seen:
            continue
        seen.add(cand)
        shared_dir = cand / "shared"
        if shared_dir.is_dir() and (shared_dir / "memory.py").is_file():
            if str(cand) not in sys.path:
                sys.path.insert(0, str(cand))
            return shared_dir
        # install layout: .../skills/trace-shared/{memory.py,...}
        if cand.name == "trace-shared" and (cand / "memory.py").is_file():
            parent = cand.parent
            if str(parent) not in sys.path:
                sys.path.insert(0, str(parent))
            # Alias trace-shared as top-level package name `shared`
            import types
            if "shared" not in sys.modules:
                pkg = types.ModuleType("shared")
                pkg.__path__ = [str(cand)]  # type: ignore[attr-defined]
                sys.modules["shared"] = pkg
            return cand
    raise ImportError("Trace shared package not found (skills/shared or trace-shared)")
