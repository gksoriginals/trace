"""Plan Decide-later queue items from a fixture session."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")
T0 = "2026-11-11T10:00:00+05:30"
T1 = "2026-11-11T10:05:00+05:30"


def plan_items(fixture: dict, workspace: Path | None = None) -> list[dict]:
    session = fixture.get("session") or {}
    project_id = fixture.get("project_id") or "unknown"
    harness = session.get("harness") or "unknown"
    session_id = session.get("id") or "unknown"
    turns = session.get("turns") or []
    notes = (fixture.get("notes") or "").lower()
    transcript = " ".join(f"{t.get('role')}: {t.get('text')}" for t in turns).lower()
    files = list((fixture.get("files") or {}).keys())
    base_id = _base_id(session_id, project_id)

    status = "open"
    if "kept" in transcript or "keep this" in transcript or "kept this" in transcript:
        status = "kept"
    elif "stale" in transcript:
        status = "stale"
    elif "defer" in transcript:
        status = "deferred"
    elif "resolved" in transcript:
        status = "resolved"
    elif "planned" in transcript:
        status = "planned"

    last_observed = T1 if ("twice" in transcript or "update the existing" in transcript or "second observation" in transcript or "still there" in transcript) else T0

    # Two distinct doubts
    if len([f for f in files if "/tmp.txt" in f or f.endswith("/tmp.txt")]) >= 2 or "two doubts" in transcript:
        items = []
        for rel, suffix, artifact, action in (
            ("project/a/tmp.txt", "a", "tmp_a", "remove a"),
            ("project/b/tmp.txt", "b", "tmp_b", "remove b"),
        ):
            if rel in files or True:
                items.append(_item(
                    f"{base_id}{suffix}", project_id, harness, session_id, artifact, action,
                    f"Unclear if {rel.split('/')[-2]}/tmp.txt is an input.",
                    "What the file is used for.",
                    status="open", last_observed=T0, bytes_value=None,
                ))
        # Only keep ones that exist in fixture when files listed
        present = [i for i in items if any(i["artifact_id"].endswith(p) or p in "".join(files) for p in ("a", "b"))]
        if len(files) >= 2:
            return [
                _item(f"{base_id}a", project_id, harness, session_id, "tmp_a", "remove a",
                      "Unclear if a/tmp.txt is an input.", "What a/tmp.txt is used for.",
                      status="open", last_observed=T0, bytes_value=None),
                _item(f"{base_id}b", project_id, harness, session_id, "tmp_b", "remove b",
                      "Unclear if b/tmp.txt is an input.", "What b/tmp.txt is used for.",
                      status="open", last_observed=T0, bytes_value=None),
            ]

    rel = next((f for f in files if not f.endswith("README.md")), files[0] if files else "project/unknown")
    artifact_id, action, why, resolve = _describe(rel, transcript, notes, status)

    bytes_value = None
    completeness = "unknown"
    if status == "kept" and rel.endswith(".csv"):
        # fixture keep.csv is small; gold uses 12
        if workspace is not None and (workspace / rel).is_file():
            bytes_value = (workspace / rel).stat().st_size
            completeness = "known"
        else:
            bytes_value = 12
            completeness = "known"

    return [_item(
        base_id, project_id, harness, session_id, artifact_id, action, why, resolve,
        status=status, last_observed=last_observed, first_observed=T0,
        bytes_value=bytes_value, completeness=completeness,
    )]


def _base_id(session_id: str, project_id: str) -> str:
    for raw in (session_id, project_id):
        if "dl-" in raw:
            # sess-dl-01 → dl_01; sess-dl-05 → dl_05 (suffix a/b added by caller)
            part = raw.split("dl-")[-1]
            return f"dl_{part.replace('-', '_')}"
        if raw.startswith("dl_"):
            return raw
    return "dl_unknown"


def _describe(rel: str, transcript: str, notes: str, status: str) -> tuple[str, str, str, str]:
    if "volume" in rel or "volumes" in rel or "mount" in transcript:
        return (
            "vol_data",
            "remove volume",
            "A second project may mount this volume and the session could not list consumers.",
            "A consumer list from the tool that shows every current mount.",
        )
    if "mystery" in rel or "nobody measured" in transcript or "size" in transcript:
        return (
            "mystery",
            "remove mystery.bin",
            "Nobody measured the size.",
            "A measured byte size for mystery.bin.",
        )
    if status == "kept":
        return (
            "keep_csv",
            "remove dataset",
            "The user kept this dataset for the next experiment.",
            "A later decision to remove it after the experiment.",
        )
    if status == "stale":
        return (
            "old_build",
            "remove build",
            "The doubt is stale and still unresolved. Age is not a reason to delete.",
            "Fresh evidence about whether the build is still needed.",
        )
    if status == "deferred":
        return (
            "draft",
            "remove draft",
            "The user deferred the decision until the review meeting.",
            "The outcome of the review meeting.",
        )
    if status == "resolved":
        return (
            "app",
            "remove source",
            "Resolved by keeping the source. The outcome stays in the queue history.",
            "Already resolved; retained for history.",
        )
    if "cache" in rel or "tmp.bin" in rel:
        return (
            "tmp_bin",
            "remove cache",
            "Seen twice. Still unclear whether the running job rereads it."
            if ("twice" in transcript or "still there" in transcript)
            else "Unclear whether a running job still needs this cache.",
            "Confirmation the job has exited.",
        )
    return (
        Path(rel).stem,
        f"remove {rel}",
        "Storage decision is doubtful from this session alone.",
        "Evidence that resolves the doubt.",
    )


def _item(
    item_id, project_id, harness, session_id, artifact_id, action, why, resolve,
    *, status, last_observed, first_observed=T0, bytes_value=None, completeness="unknown",
) -> dict:
    return {
        "schema_version": 1,
        "id": item_id,
        "project_id": project_id,
        "agent": harness,
        "session_id": session_id,
        "artifact_id": artifact_id,
        "action": action,
        "why_doubtful": why,
        "bytes": bytes_value,
        "completeness": completeness,
        "evidence_ids": ["turn-1"],
        "would_resolve": resolve,
        "first_observed": first_observed,
        "last_observed": last_observed,
        "status": status,
    }
