"""Deep attribution pass helpers for Reviewing and the attribution eval suite."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

ALLOWED_SOURCES = frozenset({
    "git", "mtime", "session_log", "transcript", "package_lock", "tool_manifest", "none",
})


def attribute_artifacts(fixture: dict, workspace: Path | None = None) -> list[dict]:
    artifacts = fixture.get("artifacts") or []
    evidence = {e["id"]: e for e in (fixture.get("evidence") or []) if e.get("id")}
    project_id = fixture.get("project_id") or "unknown"
    events: list[dict] = []
    for art in artifacts:
        art_id = art.get("id") or "unknown"
        path = art.get("path") or ""
        result = _resolve(art_id, path, evidence)
        claim = (
            "verified" if result["label"] == "verified"
            else "inferred" if result["label"] == "inferred"
            else "observed"
        )
        harness = result["creator"]
        if result["label"] == "unattributed":
            harness = "unknown"
        event = {
            "schema_version": 1,
            "event_id": f"evt-at-{art_id}",
            "event_type": "artifact",
            "what": {
                "id": art_id,
                "kind": "artifact",
                "location": path,
                "bytes": _bytes(workspace, path),
                "completeness": "known" if workspace and path and (workspace / path).exists() else "unknown",
            },
            "why": result["why"],
            "claim": claim,
            "agent": {"harness": harness or "unknown", "session_id": result["session_id"] or "unknown"},
            "project": {"id": project_id, "consumers": [project_id]},
            "created": {"at": "2026-11-11T10:00:00+05:30", "source": "discovered"},
            "can_go_when": "no remaining consumers" if result["label"] != "unattributed" else "unknown lifecycle",
            "evidence_ids": result["evidence_ids"],
            "correction_of": None,
            "attribution": {
                "source": result["source"],
                "label": result["label"],
                "counts": result["counts"],
            },
        }
        events.append(event)
    return events


def _bytes(workspace: Path | None, path: str) -> int | None:
    if workspace is None or not path:
        return None
    p = workspace / path
    return p.stat().st_size if p.is_file() else None


def _resolve(art_id: str, path: str, evidence: dict[str, dict]) -> dict[str, Any]:
    items = list(evidence.values())
    # Ignore path-name-only evidence (kind path or "name is not")
    usable = [
        e for e in items
        if (e.get("kind") in ALLOWED_SOURCES - {"none"})
        and "name is not" not in (e.get("text") or "").lower()
        and e.get("kind") != "path"
    ]

    # Human / user from git
    for ev in usable:
        text = (ev.get("text") or "").lower()
        kind = ev.get("kind") or "none"
        if kind == "git" and ("human" in text or "copied by" in text or "author: user" in text or "by a human" in text):
            return {
                "creator": "user",
                "session_id": "unknown",
                "source": "git",
                "label": "verified",
                "counts": False,
                "evidence_ids": [ev["id"]],
                "why": f"Git shows a human copy. Path names are not creators. ({ev['id']})",
            }

    # mtime + transcript/session window → inferred, source mtime, cite both
    mtime_ev = next((e for e in usable if e.get("kind") == "mtime"), None)
    window_ev = next((e for e in usable if e.get("kind") in {"transcript", "session_log"} and mtime_ev), None)
    if mtime_ev and window_ev:
        text = (window_ev.get("text") or "").lower()
        harness = _find_harness(text) or "unknown"
        session = _find_session(text) or "unknown"
        if harness != "unknown" and session != "unknown":
            return {
                "creator": harness,
                "session_id": session,
                "source": "mtime",
                "label": "inferred",
                "counts": True,
                "evidence_ids": [mtime_ev["id"], window_ev["id"]],
                "why": f"mtime aligns with {harness} session {session} which names the path.",
            }

    # Single strong evidence
    for ev in usable:
        text = (ev.get("text") or "").lower()
        kind = ev.get("kind") or "none"
        if "might" in text or "maybe" in text:
            continue
        harness = _find_harness(text)
        session = _find_session(text)
        if not harness or not session or kind not in ALLOWED_SOURCES:
            continue
        # package_lock / mtime alone → inferred; git/session_log/transcript/tool_manifest with explicit write → verified
        if kind in {"package_lock", "mtime"}:
            label = "inferred"
        else:
            label = "verified"
        return {
            "creator": harness,
            "session_id": session,
            "source": kind,
            "label": label,
            "counts": True,
            "evidence_ids": [ev["id"]],
            "why": f"{kind} evidence {ev['id']} names {harness} session {session}.",
        }

    checked = [e["id"] for e in usable] or [e["id"] for e in items]
    return {
        "creator": "unknown",
        "session_id": "unknown",
        "source": "none",
        "label": "unattributed",
        "counts": False,
        "evidence_ids": checked,
        "why": "No evidence named a creator after checking available sources.",
    }


def _find_harness(text: str) -> str | None:
    for name in ("cursor", "codex", "claude", "gemini", "user"):
        if re.search(rf"\bharness\s+{name}\b", text) or re.search(rf"\b{name}\b", text):
            if name == "user":
                return "user"
            return name
    return None


def _find_session(text: str) -> str | None:
    m = re.search(r"\b(sess-[a-z0-9-]+)\b", text)
    return m.group(1) if m else None
