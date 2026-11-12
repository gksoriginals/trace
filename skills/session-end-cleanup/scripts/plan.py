"""Plan session-end proposals, Trash moves, and Decide-later items."""

from __future__ import annotations

from pathlib import Path

T0 = "2026-11-11T10:00:00+05:30"

DISPOSABLE_HINTS = (
    "__pycache__",
    ".pytest_cache",
    "/dist/",
    "dist/",
    ".tmp",
    "scratch/",
    "/tmp-",
    "tmp-session",
    ".pyc",
)

KEEP_ALWAYS = (
    ".env",
    "package-lock.json",
    "Cargo.lock",
    "README.md",
    "/src/",
    "checkpoints/",
    ".lock",
)


def plan(fixture: dict, workspace: Path) -> dict:
    session = fixture.get("session") or {}
    project_id = fixture.get("project_id") or "unknown"
    harness = session.get("harness") or "unknown"
    session_id = session.get("id") or "unknown"
    protected = set(fixture.get("protected") or [])
    consent = list(fixture.get("consent") or [])
    notes = (fixture.get("notes") or "").lower()
    turns = session.get("turns") or []
    transcript = " ".join(f"{t.get('role')}: {t.get('text')}" for t in turns).lower()
    files = list((fixture.get("files") or {}).keys())

    proposals: list[str] = []
    queue: list[dict] = []

    shared = any(f.startswith("shared/") for f in files) or "shared" in notes
    if shared:
        for rel in files:
            if rel.startswith("shared/"):
                queue.append(_queue_item(
                    "dl_shared", project_id, harness, session_id, Path(rel).name,
                    f"remove {rel}",
                    "Other projects may use this shared store and this session could not list them.",
                    "A complete consumer list for the shared store.",
                ))
        return {"proposals": [], "trash": [], "decide_later": queue}

    # Clean tree / only source+readme
    disposable_candidates = [f for f in files if _is_disposable(f, transcript) and f not in protected]
    unexplained = [
        f for f in files
        if f not in protected
        and not _is_disposable(f, transcript)
        and not _is_source_like(f)
        and ("blob" in f or "unexplained" in transcript or "do not know" in transcript or "source of truth" in transcript)
    ]

    # In-use lock: propose nothing
    if any(f.endswith(".lock") or f.endswith("/.lock") or f == "project/.lock" for f in files) and (
        "live process" in transcript or "in-use" in transcript or "held by" in transcript or "leave it" in transcript
    ):
        return {"proposals": [], "trash": [], "decide_later": []}

    # Clean tree: only readme + src
    if not disposable_candidates and not unexplained:
        return {"proposals": [], "trash": [], "decide_later": []}

    for rel in unexplained:
        queue.append(_queue_item(
            "dl_se07" if "blob" in rel else f"dl_{Path(rel).stem}",
            project_id, harness, session_id, Path(rel).stem,
            f"remove {rel}",
            f"The session created {Path(rel).name} and never said what it is.",
            f"A purpose for {Path(rel).name}, or confirmation it is disposable.",
        ))

    for rel in disposable_candidates:
        if _is_source_like(rel) and ("dirty" in rel or "uncommitted" in transcript):
            continue
        if rel.endswith(".lock") or rel == "project/.lock":
            continue
        if rel in protected:
            continue
        proposals.append(rel)

    # Secrets stay; temp beside them can be proposed
    proposals = [p for p in proposals if p not in protected and not p.endswith(".env")]

    trash = [p for p in proposals if p in consent]

    return {
        "proposals": sorted(set(proposals)),
        "trash": trash,
        "decide_later": queue,
    }


def _is_disposable(rel: str, transcript: str) -> bool:
    if any(h in rel for h in DISPOSABLE_HINTS):
        return True
    if "scratch" in rel or "tmp" in rel.lower():
        return True
    if "dist/" in rel or rel.startswith("project/dist/"):
        return True
    if "__pycache__" in rel or ".pytest_cache" in rel:
        return True
    name = Path(rel).name
    if name.startswith(".tmp") or name.endswith(".tmp"):
        return True
    if "disposable" in transcript and name in transcript:
        return True
    return False


def _is_source_like(rel: str) -> bool:
    if any(x in rel for x in ("/src/", "README", "package.json", "package-lock", "Cargo.toml", ".env", "checkpoints")):
        return True
    if rel.endswith((".py", ".ts", ".js", ".tsx", ".rs", ".go")) and "scratch" not in rel and "__pycache__" not in rel:
        return True
    return False


def _queue_item(item_id, project_id, harness, session_id, artifact_id, action, why, resolve) -> dict:
    return {
        "schema_version": 1,
        "id": item_id,
        "project_id": project_id,
        "agent": harness,
        "session_id": session_id,
        "artifact_id": artifact_id,
        "action": action,
        "why_doubtful": why,
        "bytes": None,
        "completeness": "unknown",
        "evidence_ids": ["turn-1"],
        "would_resolve": resolve,
        "first_observed": T0,
        "last_observed": T0,
        "status": "open",
    }
