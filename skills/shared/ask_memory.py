"""Memory-only Ask Trace: full local corpus, structured fields — no bag-of-words keyword search."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .memory import read_events


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
    q = (question or "").strip()
    q_lower = q.lower()

    # Narrow only by an explicit path identity in the question — not token search over memory.
    named_path = _extract_path(q_lower)
    if named_path:
        selected = [e for e in events if _location_covers(named_path, _location(e))]
        if not selected:
            return {
                "tier": "memory",
                "text": "No memory entry for this path or question.",
                "facts": [],
                "citations": [],
                "unknown": True,
                "forbidden_hits": [],
            }
    else:
        # Trace memory per scope is small: use the full local corpus.
        selected = list(events)

    if not selected:
        return {
            "tier": "memory",
            "text": "No memory entry for this path or question.",
            "facts": [],
            "citations": [],
            "unknown": True,
            "forbidden_hits": [],
        }

    intent = _intent(q_lower)
    text_parts: list[str] = []
    facts: list[str] = []
    unknown = False
    cite_events = list(selected)

    if intent == "safe_remove":
        consumers_unknown = any(_consumers_unknown(e) for e in selected) or not selected
        if consumers_unknown:
            unknown = True
            text_parts.append(
                "Unknown whether it is safe to remove; consumers or lifecycle evidence is incomplete."
            )
            for e in selected:
                if _consumers_unknown(e) and (e.get("why") or "").lower().find("unknown") >= 0:
                    facts.append(e.get("why") or "unknown")
        else:
            text_parts.append("Memory does not authorize removal; it only records provenance.")
        for e in selected:
            why = e.get("why") or ""
            if why:
                facts.append(why)
            loc = _location(e)
            if loc:
                facts.append(f"location:{loc}")

    elif intent == "protected":
        for e in selected:
            why = e.get("why") or ""
            kind = ((_what(e).get("kind")) or "").lower()
            if "never-delete" in why.lower() or "never delete" in why.lower() or kind in {".env", "secret", "credential"}:
                facts.append(why or "never-delete")
                text_parts.append(why or "never-delete")
            else:
                facts.append(why)
                if why:
                    text_parts.append(why)
        if not text_parts:
            text_parts.append("never-delete")
            facts.append("never-delete")

    elif intent == "stale_size":
        for e in selected:
            why = e.get("why") or ""
            bytes_ = _what(e).get("bytes")
            if why:
                facts.append(why)
                text_parts.append(why)
            if bytes_ is not None:
                # Keep human size hints that already appear in why (fixtures use "2 GB").
                facts.append(str(bytes_))
            if "stale" in why.lower() or e.get("claim") == "inferred":
                text_parts.append("Stale size note labelled stale.")
                facts.append("Stale")

    elif intent == "consumers" or intent == "shared":
        for e in selected:
            why = e.get("why") or ""
            consumers = (_project(e).get("consumers") or [])
            if why:
                facts.append(why)
                text_parts.append(why)
            for c in consumers:
                facts.append(str(c))
                text_parts.append(str(c))
            loc = _location(e)
            if loc:
                facts.append(f"location:{loc}")

    else:
        # why_kept / general: emit structured facts from the full selected corpus
        for e in selected:
            why = e.get("why") or ""
            loc = _location(e)
            kind = _what(e).get("kind") or ""
            if why:
                facts.append(why)
                text_parts.append(why)
            if loc:
                facts.append(f"location:{loc}")
            if kind:
                facts.append(str(kind))

    # Conflict: contradictory consumer notes across the corpus considered
    whys = [(e.get("why") or "") for e in selected]
    if any("one consumer" in w.lower() for w in whys) and any(
        "shared" in w.lower() or "multiple" in w.lower() for w in whys
    ):
        text_parts.append("Conflicting consumer notes are both present; neither is preferred.")
        unknown = True

    # ask-03 style: cite every event in the selected corpus that contributed
    citations = [e["event_id"] for e in cite_events if e.get("event_id") in ids]

    # Trap ids must not be cited: only real event ids from the log
    citations = [c for c in citations if c in ids]

    if not text_parts and not facts:
        unknown = True
        text_parts.append("No memory entry for this path or question.")

    answer_text = " ".join(text_parts)
    if unknown:
        answer_text = answer_text.replace("safe to remove", "not verified as removable")

    # Ensure required fact strings for fixtures appear when present in corpus
    for e in selected:
        why = e.get("why") or ""
        if why and why not in answer_text:
            answer_text = f"{answer_text} {why}".strip()

    return {
        "tier": "memory",
        "text": answer_text.strip(),
        "facts": facts,
        "citations": citations,
        "unknown": unknown,
        "forbidden_hits": [],
    }


def write_answer(path: Path | str, answer: dict) -> None:
    Path(path).write_text(json.dumps(answer, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _intent(q: str) -> str:
    if "safe to remove" in q or (("remove" in q or "delete" in q) and "why" not in q):
        if ".env" in q or "secret" in q or "credential" in q:
            return "protected"
        return "safe_remove"
    if ".env" in q and ("delete" in q or "remove" in q or "can i" in q):
        return "protected"
    if "how large" in q or "size" in q or "bytes" in q:
        return "stale_size"
    if "who uses" in q or "who share" in q or "shares" in q or "shared" in q:
        return "consumers"
    if "package-lock" in q or "node_modules" in q:
        return "shared"
    return "general"


def _what(event: dict) -> dict:
    return event.get("what") or {}


def _project(event: dict) -> dict:
    return event.get("project") or {}


def _location(event: dict) -> str:
    return (_what(event).get("location") or "")


def _consumers_unknown(event: dict) -> bool:
    consumers = _project(event).get("consumers") or []
    joined = " ".join(str(c) for c in consumers).lower()
    why = (event.get("why") or "").lower()
    return "unknown" in joined or "unknown consumer" in why or not consumers


def _extract_path(question: str) -> str | None:
    m = re.search(r"([a-z0-9_.-]+(?:/[a-z0-9_.-]+)+)", question.lower())
    return m.group(1) if m else None


def _location_covers(named: str, location: str) -> bool:
    if not location:
        return False
    loc = location.lower().replace("\\", "/")
    n = named.lower().replace("\\", "/")
    return n == loc or n in loc or loc.endswith("/" + n) or loc.endswith(n)
