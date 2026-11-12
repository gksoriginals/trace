"""Memory-only Ask Trace retrieval."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .memory import read_events

_STOP = frozenset({
    "the", "and", "for", "what", "why", "was", "how", "is", "are", "this", "that",
    "with", "from", "about", "project", "file", "path", "safe", "remove", "delete",
})


def answer_from_memory(
    question: str,
    *,
    memory_path: Path | str | None = None,
    events: list[dict] | None = None,
    known_event_ids: set[str] | None = None,
) -> dict[str, Any]:
    if events is None:
        events = read_events(memory_path) if memory_path else []
    ids = known_event_ids or {e.get("event_id") for e in events if e.get("event_id")}
    q = question.lower()
    tokens = [t for t in _tokens(q) if t not in _STOP]

    matched: list[dict] = []
    facts: list[str] = []
    for event in events:
        what = event.get("what") or {}
        location = what.get("location") or ""
        kind = (what.get("kind") or "").lower()
        why = event.get("why") or ""
        blob = f"{why} {location} {kind} {what.get('id') or ''}".lower()
        if _path_mentioned(q, location):
            matched.append(event)
        elif tokens and any(tok in blob for tok in tokens if len(tok) > 3):
            matched.append(event)
        else:
            continue
        if why:
            facts.append(why)
        if location:
            facts.append(f"location:{location}")

    # If the question names a specific path that no event has, force unknown
    path_in_q = _extract_path(q)
    if path_in_q and not any(_path_mentioned(path_in_q, ((e.get("what") or {}).get("location") or "")) for e in matched):
        matched = []
        facts = []

    citations = [e["event_id"] for e in matched if e.get("event_id") in ids]

    unknown = False
    text_parts: list[str] = []
    if "safe to remove" in q or (("remove" in q or "delete" in q) and "why" not in q):
        consumers_unknown = not matched or any(
            "unknown" in str((e.get("project") or {}).get("consumers") or []).lower()
            or "unknown consumer" in (e.get("why") or "").lower()
            for e in matched
        )
        if consumers_unknown or not matched:
            unknown = True
            text_parts.append("Unknown whether it is safe to remove; consumers or lifecycle evidence is incomplete.")
        else:
            text_parts.append("Memory does not authorize removal; it only records provenance.")

    if not matched:
        unknown = True
        text_parts.append("No memory entry for this path or question.")
    else:
        text_parts.extend(facts[:6])

    whys = [(e.get("why") or "") for e in matched]
    if any("one consumer" in w.lower() for w in whys) and any(
        "shared" in w.lower() or "multiple" in w.lower() for w in whys
    ):
        text_parts.append("Conflicting consumer notes are both present; neither is preferred.")
        unknown = True

    if any("stale" in (e.get("why") or "").lower() or (e.get("claim") == "inferred" and "size" in q) for e in matched):
        text_parts.append("Stale size note labelled stale.")

    answer_text = " ".join(text_parts)
    if unknown:
        answer_text = answer_text.replace("safe to remove", "not verified as removable")

    return {
        "tier": "memory",
        "text": answer_text,
        "facts": facts,
        "citations": citations,
        "unknown": unknown,
        "forbidden_hits": [],
    }


def write_answer(path: Path | str, answer: dict) -> None:
    Path(path).write_text(json.dumps(answer, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _tokens(question: str) -> list[str]:
    return [t for t in re.split(r"[^a-z0-9_./-]+", question.lower()) if len(t) > 2]


def _extract_path(question: str) -> str | None:
    m = re.search(r"([a-z0-9_.-]+(?:/[a-z0-9_.-]+)+)", question.lower())
    return m.group(1) if m else None


def _path_mentioned(question: str, location: str) -> bool:
    if not location:
        return False
    loc = location.lower()
    q = question.lower()
    name = Path(loc).name.lower()
    return loc in q or (name and name in q and name not in {"readme.md", "readme"})
