"""Version-1 contracts for memory events and the project index."""

from __future__ import annotations

from typing import Any

EVENT_TYPES = frozenset({
    "artifact",
    "setup_change",
    "cleanup_outcome",
    "coverage_receipt",
    "correction",
    "lesson",
    "decision",
})
CLAIMS = frozenset({"observed", "inferred", "verified"})
CREATED_SOURCES = frozenset({"observed", "inferred", "discovered"})
COMPLETENESS = frozenset({"known", "partial", "unknown"})


class SchemaError(ValueError):
    pass


def require_mapping(value: Any, label: str) -> dict:
    if not isinstance(value, dict):
        raise SchemaError(f"{label} must be an object")
    return value


def require_nonempty_str(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise SchemaError(f"{label} must be a non-empty string")
    return value


def require_list(value: Any, label: str) -> list:
    if not isinstance(value, list):
        raise SchemaError(f"{label} must be a list")
    return value


def validate_memory_event(event: dict) -> dict:
    """Validate a version-1 memory event. Returns the same object on success."""
    event = require_mapping(event, "event")
    if event.get("schema_version") != 1:
        raise SchemaError("schema_version must be 1")
    require_nonempty_str(event.get("event_id"), "event_id")
    event_type = event.get("event_type")
    if event_type not in EVENT_TYPES:
        raise SchemaError(f"event_type must be one of {sorted(EVENT_TYPES)}")

    what = require_mapping(event.get("what"), "what")
    require_nonempty_str(what.get("id"), "what.id")
    require_nonempty_str(what.get("kind"), "what.kind")
    require_nonempty_str(what.get("location"), "what.location")
    if "bytes" in what and what["bytes"] is not None and not isinstance(what["bytes"], int):
        raise SchemaError("what.bytes must be an int or null")
    if "completeness" in what and what["completeness"] is not None:
        if what["completeness"] not in COMPLETENESS:
            raise SchemaError("what.completeness must be known, partial, unknown, or absent")

    require_nonempty_str(event.get("why"), "why")
    claim = event.get("claim")
    if claim not in CLAIMS:
        raise SchemaError("claim must be observed, inferred, or verified")

    agent = require_mapping(event.get("agent"), "agent")
    require_nonempty_str(agent.get("harness"), "agent.harness")
    require_nonempty_str(agent.get("session_id"), "agent.session_id")

    project = require_mapping(event.get("project"), "project")
    require_nonempty_str(project.get("id"), "project.id")
    consumers = project.get("consumers")
    if consumers is not None:
        require_list(consumers, "project.consumers")

    created = require_mapping(event.get("created"), "created")
    require_nonempty_str(created.get("at"), "created.at")
    if created.get("source") not in CREATED_SOURCES:
        raise SchemaError("created.source must be observed, inferred, or discovered")

    require_nonempty_str(event.get("can_go_when"), "can_go_when")
    evidence = require_list(event.get("evidence_ids"), "evidence_ids")
    if not evidence:
        raise SchemaError("evidence_ids must be non-empty")
    if "correction_of" not in event:
        raise SchemaError("correction_of is required (use null when not a correction)")
    correction = event.get("correction_of")
    if correction is not None and (not isinstance(correction, str) or not correction.strip()):
        raise SchemaError("correction_of must be a non-empty string or null")
    return event


def validate_index(document: dict) -> dict:
    document = require_mapping(document, "index")
    if document.get("schema_version") != 1:
        raise SchemaError("index schema_version must be 1")
    projects = require_list(document.get("projects"), "projects")
    for i, project in enumerate(projects):
        project = require_mapping(project, f"projects[{i}]")
        require_nonempty_str(project.get("id"), f"projects[{i}].id")
        # ADR-0007: memory_dir preferred; memory_log kept for older rows
        mem = project.get("memory_dir") or project.get("memory_log")
        require_nonempty_str(mem, f"projects[{i}].memory_dir")
        if "roots" in project:
            require_list(project.get("roots"), f"projects[{i}].roots")
        if "opt_out" in project and not isinstance(project["opt_out"], bool):
            raise SchemaError(f"projects[{i}].opt_out must be a bool")
    return document
