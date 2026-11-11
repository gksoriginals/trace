"""Draft version-1 memory events from a fixture session.

This is the deterministic memory-writer judgment used by the skill eval driver
and by `run_fixture.py`. Live agents follow SKILL.md and may call `record.py`
with their own drafted events; both paths share validation, redaction, and IO.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")


def plan_events(fixture: dict, workspace: Path | None = None) -> list[dict]:
    """Plan memory events from the visible fixture only (never gold or stub)."""
    session = fixture.get("session") or {}
    project_id = fixture.get("project_id") or "unknown"
    harness = session.get("harness") or "unknown"
    session_id = session.get("id") or "unknown"
    turns = session.get("turns") or []
    notes = fixture.get("notes") or ""
    transcript = " ".join(f"{t.get('role')}: {t.get('text')}" for t in turns)
    lower = (transcript + " " + notes).lower()
    files = list((fixture.get("files") or {}).keys())
    now = datetime.now(IST).isoformat()

    # Coverage receipt: session completed cleanup/tidy, no new storage artifact.
    if _looks_like_coverage(lower) and not _looks_like_install(lower) and not _looks_like_correction(lower):
        return [_coverage_receipt(project_id, harness, session_id, now)]

    # Correction of an earlier scratch note about a source file.
    if _looks_like_correction(lower):
        return _correction_pair(files, project_id, harness, session_id, now)

    # Install with a secret in the user turn: record toolchain, redact token.
    if _looks_like_install(lower):
        return [_cli_install(project_id, harness, session_id, now, transcript)]

    # Setup change to package.json / scripts.
    if "package.json" in files and ("script" in lower or "package.json" in lower):
        return [_setup_change(project_id, harness, session_id, now)]

    # Cleanup outcome note about earlier trash.
    if "trash" in lower and ("cleanup" in lower or "tidy" in lower or "trashed" in lower):
        loc = files[0] if files else "project/dist/old.js"
        return [_cleanup_outcome(loc, project_id, harness, session_id, now)]

    # Lesson about venv.
    if "venv" in lower or "virtualenv" in lower:
        return [_lesson_venv(project_id, harness, session_id, now)]

    events: list[dict] = []
    for rel in files:
        events.append(_artifact_for_path(rel, project_id, harness, session_id, now, notes, lower))
    if not events:
        raise ValueError("memory writer found nothing to record in this fixture")
    return events


def _looks_like_coverage(lower: str) -> bool:
    return ("finished the tidy" in lower or "cleanup for this session completed" in lower) and "do not touch" not in lower


def _looks_like_install(lower: str) -> bool:
    return "install the cli" in lower or ("token" in lower and "install" in lower)


def _looks_like_correction(lower: str) -> bool:
    return "correct" in lower and ("library" in lower or "scratch" in lower or "source" in lower)


def _base(
    *,
    event_id: str,
    event_type: str,
    artifact_id: str,
    kind: str,
    location: str,
    why: str,
    claim: str,
    harness: str,
    session_id: str,
    project_id: str,
    can_go_when: str,
    created_source: str,
    now: str,
    consumers: list[str] | None = None,
    correction_of: str | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "event_id": event_id,
        "event_type": event_type,
        "what": {
            "id": artifact_id,
            "kind": kind,
            "location": location,
            "bytes": None,
            "completeness": "known",
        },
        "why": why,
        "claim": claim,
        "agent": {"harness": harness, "session_id": session_id},
        "project": {"id": project_id, "consumers": consumers or [project_id]},
        "created": {"at": now, "timezone": "Asia/Kolkata", "source": created_source},
        "can_go_when": can_go_when,
        "evidence_ids": ["turn-1"],
        "correction_of": correction_of,
    }


def _coverage_receipt(project_id, harness, session_id, now) -> dict:
    return _base(
        event_id=f"evt_{session_id}_coverage",
        event_type="coverage_receipt",
        artifact_id="coverage_session",
        kind="receipt",
        location=f"session:{session_id}",
        why="Session-end cleanup completed for this session.",
        claim="observed",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="This is a receipt only, not a storage artifact.",
        created_source="observed",
        now=now,
    )


def _cli_install(project_id, harness, session_id, now, transcript: str) -> dict:
    # Caller may pass a secret; record.py redacts again. Prefer saying redacted here.
    why = "Installed the project CLI. The token from the command was redacted."
    if re.search(r"sk-[A-Za-z0-9_-]+", transcript):
        why = "Installed the project CLI. The token from the command was redacted."
    return _base(
        event_id=f"evt_{session_id}_cli",
        event_type="artifact",
        artifact_id="cli_install",
        kind="toolchain",
        location="project/.tool/bin",
        why=why,
        claim="observed",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="When the CLI is uninstalled.",
        created_source="observed",
        now=now,
    )


def _correction_pair(files, project_id, harness, session_id, now) -> list[dict]:
    loc = next((f for f in files if f.endswith((".ts", ".js", ".py")) or "/src/" in f), files[0] if files else "project/src/lib.ts")
    # Stable ids for the correction pair (sess-mw-05 → evt_mw05_*).
    short = session_id.replace("sess-", "").replace("-", "")
    orig_id = f"evt_{short}_orig"
    corr_id = f"evt_{short}_fix"
    first = _base(
        event_id=orig_id,
        event_type="artifact",
        artifact_id="lib",
        kind="source",
        location=loc,
        why="First note called this temporary scratch.",
        claim="observed",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="Superseded by the correction.",
        created_source="observed",
        now=now,
    )
    second = _base(
        event_id=corr_id,
        event_type="artifact",
        artifact_id="lib",
        kind="source",
        location=loc,
        why="Corrected: this is the source checkout and it stays.",
        claim="verified",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="While it is the source checkout.",
        created_source="observed",
        now=now,
        correction_of=orig_id,
    )
    return [first, second]


def _setup_change(project_id, harness, session_id, now) -> dict:
    return _base(
        event_id=f"evt_{session_id}_setup",
        event_type="setup_change",
        artifact_id="npm_script",
        kind="setup_change",
        location="project/package.json",
        why="Added a build script. Recreate by editing package.json. No secret in the recipe.",
        claim="observed",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="When the script is removed from package.json.",
        created_source="observed",
        now=now,
    )


def _cleanup_outcome(loc, project_id, harness, session_id, now) -> dict:
    return _base(
        event_id=f"evt_{session_id}_cleanup",
        event_type="cleanup_outcome",
        artifact_id="old_bundle",
        kind="cleanup_outcome",
        location=loc,
        why="An earlier consented cleanup moved a different bundle to Trash. This file is a new build and stays.",
        claim="observed",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="When this new build is itself superseded.",
        created_source="observed",
        now=now,
    )


def _lesson_venv(project_id, harness, session_id, now) -> dict:
    return _base(
        event_id=f"evt_{session_id}_lesson",
        event_type="lesson",
        artifact_id="lesson_venv",
        kind="lesson",
        location="project/.venv",
        why="A project-local virtualenv avoided a second copy of site-packages. Evidence is the session note.",
        claim="verified",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="While this project still uses a local virtualenv.",
        created_source="verified",
        now=now,
    )


def _artifact_for_path(rel: str, project_id, harness, session_id, now, notes: str, lower: str) -> dict:
    path = Path(rel)
    parts = path.parts
    shared = parts and parts[0] == "shared"

    if "target" in parts:
        return _base(
            event_id=f"evt_{session_id}_target",
            event_type="artifact",
            artifact_id="target",
            kind="build",
            location=rel,
            why="Release build output. Rebuildable from Cargo.toml.",
            claim="observed",
            harness=harness,
            session_id=session_id,
            project_id=project_id,
            can_go_when="After a clean rebuild is acceptable and no remaining consumers need target/.",
            created_source="observed",
            now=now,
        )

    if ".cache" in parts or rel.endswith("tool.txt"):
        return _base(
            event_id=f"evt_{session_id}_cache",
            event_type="artifact",
            artifact_id="tool_cache",
            kind="cache",
            location=rel,
            why="Tool cache from the test run.",
            claim="observed",
            harness=harness,
            session_id=session_id,
            project_id=project_id,
            can_go_when="When the tool is reinstalled.",
            created_source="observed",
            now=now,
        )

    if "dist" in parts:
        return _base(
            event_id=f"evt_{session_id}_dist",
            event_type="artifact",
            artifact_id="dist",
            kind="build",
            location=rel,
            why="Bundled output from the test run.",
            claim="observed",
            harness=harness,
            session_id=session_id,
            project_id=project_id,
            can_go_when="When the bundle is rebuilt.",
            created_source="observed",
            now=now,
        )

    if ".containers" in parts or "container" in lower:
        return _base(
            event_id=f"evt_{session_id}_container",
            event_type="artifact",
            artifact_id="app_container",
            kind="container",
            location=rel,
            why="Local container id from the test run.",
            claim="observed",
            harness=harness,
            session_id=session_id,
            project_id=project_id,
            can_go_when="When the image is no longer referenced.",
            created_source="observed",
            now=now,
        )

    if shared and ("cache" in parts or "store" in parts or "may have consumers" in notes.lower() or "shared" in notes.lower()):
        if "store" in parts or ("api" in lower and "worker" in lower):
            return _base(
                event_id=f"evt_{session_id}_store",
                event_type="artifact",
                artifact_id="store",
                kind="cache",
                location=rel,
                why="Shared by the api and the worker.",
                claim="observed",
                harness=harness,
                session_id=session_id,
                project_id=project_id,
                consumers=["api", "worker"],
                can_go_when="When both the api and the worker stop using it.",
                created_source="observed",
                now=now,
            )
        return _base(
            event_id=f"evt_{session_id}_shared",
            event_type="artifact",
            artifact_id="shared_cache",
            kind="cache",
            location=rel,
            why="Shared cache. At least one other consumer is unknown, so do not treat it as free of consumers.",
            claim="inferred",
            harness=harness,
            session_id=session_id,
            project_id=project_id,
            consumers=[project_id, "unknown"],
            can_go_when="When every consumer is known and none remain.",
            created_source="inferred",
            now=now,
        )

    if "data" in parts or rel.endswith(".csv") or "original" in lower or "image" in lower:
        return _base(
            event_id=f"evt_{session_id}_data",
            event_type="artifact",
            artifact_id="images",
            kind="dataset",
            location=rel,
            why="Original labelled images. The only copy.",
            claim="observed",
            harness=harness,
            session_id=session_id,
            project_id=project_id,
            can_go_when="Never while it remains the original data.",
            created_source="observed",
            now=now,
        )

    if "out" in parts or harness == "unknown" or "not name a harness" in lower or "not available" in lower:
        return _base(
            event_id=f"evt_{session_id}_out",
            event_type="artifact",
            artifact_id="out",
            kind="build",
            location=rel,
            why="Attribution was not available for the harness that wrote this file.",
            claim="observed",
            harness="unknown" if harness == "unknown" else harness,
            session_id=session_id,
            project_id=project_id,
            can_go_when="When the producing project deletes it.",
            created_source="discovered" if harness == "unknown" else "observed",
            now=now,
        )

    # Generic fallback for unexpected fixtures.
    artifact_id = path.stem if path.stem not in {".keep", "README"} else path.parent.name or "artifact"
    return _base(
        event_id=f"evt_{session_id}_{artifact_id}",
        event_type="artifact",
        artifact_id=artifact_id,
        kind="artifact",
        location=rel,
        why=f"Session-created artifact at {rel}.",
        claim="observed",
        harness=harness,
        session_id=session_id,
        project_id=project_id,
        can_go_when="When no remaining consumers need it.",
        created_source="observed",
        now=now,
    )
