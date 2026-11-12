#!/usr/bin/env python3
"""Prepare Home insights.md from memory + decide-later (mode 1 helper / mode 2 target)."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

SKILLS_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SKILLS_ROOT))

from shared.frontmatter import dump_frontmatter, load_frontmatter  # noqa: E402
from shared.io import atomic_write_text  # noqa: E402
from shared.memory import read_events, set_event_status  # noqa: E402
from shared.queue import load_queue  # noqa: E402


def prepare(
    *,
    memory_path: Path,
    decide_later_path: Path,
    insights_path: Path,
    project_id: str,
    retention_days: int | None = None,
) -> str:
    events = read_events(memory_path)
    queue = []
    if decide_later_path.is_file():
        if decide_later_path.suffix == ".json":
            queue = load_queue(decide_later_path)
        else:
            meta, body = load_frontmatter(decide_later_path.read_text(encoding="utf-8"))
            queue = meta.get("items") or []
            if not queue and body.strip().startswith("{"):
                queue = json.loads(body).get("items") or []

    lines = [
        f"# Insights — {project_id}",
        "",
        f"_Updated {datetime.now(timezone.utc).isoformat()}_",
        "",
    ]
    active = [e for e in events if (e.get("status") or "active") != "done"]
    for event in active[-12:]:
        origin = "skill"
        et = event.get("event_type") or "event"
        why = (event.get("why") or "").strip().split("\n")[0]
        loc = ((event.get("what") or {}).get("location")) or ""
        lines.append(f"## {et}: {(event.get('what') or {}).get('kind') or event.get('event_id')}")
        lines.append(f"- origin: {origin}")
        lines.append(f"- id: `{event.get('event_id')}`")
        if loc:
            lines.append(f"- location: `{loc}`")
        lines.append(f"- {why}")
        lines.append("")

    open_q = [i for i in queue if (i.get("status") or "") in {"open", "planned", "deferred"}]
    if open_q:
        lines.append("## Decide later")
        for item in open_q:
            lines.append(
                f"- **{item.get('status')}** `{item.get('id')}` — {item.get('why_doubtful') or item.get('action')}"
            )
        lines.append("")

    text = "\n".join(lines)
    atomic_write_text(insights_path, dump_frontmatter({
        "schema_version": 1,
        "project_id": project_id,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "card_count": len(active),
    }, text))

    if retention_days is not None and memory_path.is_dir():
        cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
        for event in events:
            if (event.get("status") or "") != "done":
                continue
            created = ((event.get("created") or {}).get("at")) or ""
            try:
                when = datetime.fromisoformat(created.replace("Z", "+00:00"))
            except ValueError:
                continue
            if when < cutoff:
                safe = event["event_id"]
                path = memory_path / f"{safe}.md"
                if path.is_file():
                    path.unlink()

    return text


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--memory", type=Path, required=True)
    parser.add_argument("--decide-later", type=Path, required=True)
    parser.add_argument("--insights", type=Path, required=True)
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--retention-days", type=int, default=None)
    parser.add_argument("--mark-done", action="append", default=[])
    args = parser.parse_args(argv)
    for event_id in args.mark_done:
        if args.memory.is_dir():
            set_event_status(args.memory, event_id, "done")
    prepare(
        memory_path=args.memory,
        decide_later_path=args.decide_later,
        insights_path=args.insights,
        project_id=args.project_id,
        retention_days=args.retention_days,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
