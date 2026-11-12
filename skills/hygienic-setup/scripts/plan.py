"""Plan hygienic setup locations, created files, memory events, and queue items."""

from __future__ import annotations

from pathlib import Path

T0 = "2026-11-11T10:00:00+05:30"


def plan(fixture: dict, workspace: Path) -> dict:
    session = fixture.get("session") or {}
    project_id = fixture.get("project_id") or "unknown"
    harness = session.get("harness") or "unknown"
    session_id = session.get("id") or "unknown"
    notes = (fixture.get("notes") or "").lower()
    turns = session.get("turns") or []
    transcript = " ".join(f"{t.get('role')}: {t.get('text')}" for t in turns).lower()
    files = list((fixture.get("files") or {}).keys())

    # Refuse protected Mail destination
    if "mail" in notes or "protected/mail" in notes or "mail/note" in transcript:
        return {
            "create_files": {},
            "setup": {"locations": []},
            "memory_events": [_event(
                "mail_install", "toolchain", "protected/Mail/note.txt",
                "Refused install under a protected Mail path.",
                "observed", harness, session_id, project_id,
                "Never while the destination stays protected.",
                event_type="decision",
            )],
            "decide_later": [_queue(
                "dl_hs08", project_id, harness, session_id, "mail_install",
                "install under Mail",
                "The only suggested destination is a protected Mail path.",
                "A non-protected project-local install path.",
            )],
        }

    # Shared model weights — record shared location, do not copy
    if any(f.startswith("shared/models/") for f in files) or "shared model" in notes or "weights" in transcript:
        loc = next(f for f in files if "weights" in f or f.startswith("shared/models/"))
        return _reuse(
            loc, "weights", "model",
            "Using the shared model store; will not copy weights into the project.",
            harness, session_id, project_id,
            "When every consumer stops needing these weights.",
            why_key="shared model store",
        )

    # Shared image already local
    if any(f.startswith("shared/images/") for f in files) or "already local" in transcript:
        loc = next(f for f in files if f.startswith("shared/images/") or f.endswith(".tar"))
        return _reuse(
            loc, "app_image", "container",
            "Container image is already local; not saving a second copy.",
            harness, session_id, project_id,
            "When the image is unused.",
            why_key="already local",
        )

    # Shared pnpm store, two consumers
    if any("pnpm" in f for f in files) or "pnpm" in notes or "both consumers" in transcript:
        loc = next(f for f in files if "pnpm" in f)
        event = _event(
            "pnpm_store", "cache", loc,
            "One pnpm store for both consumers (api and web); no second copy.",
            "observed", harness, session_id, project_id,
            "When both consumers stop using the store.",
            consumers=["api", "web"],
        )
        return {
            "create_files": {},
            "setup": {"locations": [{"id": "pnpm_store", "path": loc}]},
            "memory_events": [event],
            "decide_later": [],
        }

    # npm ci project-local
    if "package-lock.json" in files or "package.json" in "".join(files):
        if any("package-lock.json" in f for f in files) or "npm" in transcript:
            path = "project/node_modules/.keep"
            return {
                "create_files": {path: "installed\n"},
                "setup": {"locations": [{"id": "node_modules", "path": path}]},
                "memory_events": [_event(
                    "node_modules", "dependencies", path,
                    "Project-local install recorded so it can be recreated from package-lock.json.",
                    "observed", harness, session_id, project_id,
                    "After the project no longer depends on these packages.",
                )],
                "decide_later": [],
            }

    # Python venv
    if any("requirements.txt" in f for f in files) or "venv" in transcript or "virtualenv" in transcript:
        path = "project/.venv/pyvenv.cfg"
        return {
            "create_files": {path: "home = project\n"},
            "setup": {"locations": [{"id": "venv", "path": path}]},
                "memory_events": [_event(
                    "venv", "environment", path,
                    "Created a project-local virtualenv; not exporting site-packages.",
                    "observed", harness, session_id, project_id,
                    "When the project drops the virtualenv.",
                )],
            "decide_later": [],
        }

    # Existing Rust target — reuse
    if any("Cargo.toml" in f for f in files) or any("/target/" in f or f.endswith("target/.keep") for f in files):
        loc = next((f for f in files if "target" in f), "project/target/.keep")
        return _reuse(
            loc, "target", "build",
            "Rust target already present; reusing it instead of copying.",
            harness, session_id, project_id,
            "After a clean rebuild is acceptable and no remaining consumers need target/.",
            why_key="already present",
        )

    # Original dataset
    if any("/data/" in f for f in files) or "dataset" in transcript or "raw" in transcript:
        loc = next(f for f in files if "/data/" in f or f.endswith(".csv"))
        return {
            "create_files": {},
            "setup": {"locations": [{"id": "raw", "path": loc}]},
            "memory_events": [_event(
                "raw", "dataset", loc,
                "This is the original dataset; source of truth, not a disposable copy.",
                "observed", harness, session_id, project_id,
                "Never while it remains the original dataset.",
            )],
            "decide_later": [],
        }

    # Fallback: refuse to invent
    return {
        "create_files": {},
        "setup": {"locations": []},
        "memory_events": [],
        "decide_later": [],
    }


def _reuse(loc, artifact_id, kind, why, harness, session_id, project_id, can_go, why_key: str):
    # Ensure why contains the expected substring key
    if why_key not in why:
        why = f"{why} ({why_key})"
    return {
        "create_files": {},
        "setup": {"locations": [{"id": artifact_id, "path": loc}]},
        "memory_events": [_event(artifact_id, kind, loc, why, "observed", harness, session_id, project_id, can_go)],
        "decide_later": [],
    }


def _event(artifact_id, kind, location, why, claim, harness, session_id, project_id, can_go, consumers=None, event_type="artifact"):
    return {
        "schema_version": 1,
        "event_id": f"evt_{session_id}_{artifact_id}",
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
        "created": {"at": T0, "timezone": "Asia/Kolkata", "source": "observed"},
        "can_go_when": can_go,
        "evidence_ids": ["turn-1"],
        "correction_of": None,
    }


def _queue(item_id, project_id, harness, session_id, artifact_id, action, why, resolve):
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
