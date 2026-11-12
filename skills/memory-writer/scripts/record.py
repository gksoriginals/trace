#!/usr/bin/env python3
"""Append validated memory events and update the project index."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILL_ROOT = SCRIPTS.parent
SKILLS_ROOT = SKILL_ROOT.parent
sys.path.insert(0, str(SKILLS_ROOT))
# install layout
_install_shared = SKILL_ROOT.parent / "trace-shared"
if _install_shared.is_dir():
    import types
    if "shared" not in sys.modules:
        pkg = types.ModuleType("shared")
        pkg.__path__ = [str(_install_shared)]  # type: ignore[attr-defined]
        sys.modules["shared"] = pkg
    sys.path.insert(0, str(SKILL_ROOT.parent))

from shared.index import default_index_path, upsert_project
from shared.memory import append_events, default_memory_log
from shared.schemas import SchemaError


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Append Trace memory events")
    parser.add_argument("--project-root", type=Path, help="Project root; sets default memory log")
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--memory-log", type=Path, help="Override memory JSONL path")
    parser.add_argument("--index", type=Path, help="Override project index path")
    parser.add_argument("--display-name", default=None)
    parser.add_argument("--root", action="append", dest="roots", default=None)
    parser.add_argument("--opt-out", action="store_true")
    parser.add_argument("--events", required=True, help="Path to JSON list, or - for stdin")
    parser.add_argument("--no-redact", action="store_true")
    args = parser.parse_args(argv)

    try:
        events = _load_events(args.events)
        memory_log = args.memory_log
        if memory_log is None:
            if not args.project_root:
                raise SchemaError("--memory-log or --project-root is required")
            memory_log = default_memory_log(args.project_root)
        written = append_events(memory_log, events, redact=not args.no_redact)
        index_path = args.index or default_index_path()
        roots = args.roots
        if roots is None and args.project_root is not None:
            roots = [str(args.project_root.expanduser().resolve())]
        upsert_project(
            index_path,
            project_id=args.project_id,
            memory_log=memory_log,
            display_name=args.display_name,
            roots=roots,
            opt_out=args.opt_out,
        )
    except (SchemaError, OSError, json.JSONDecodeError) as exc:
        print(f"record failed: {exc}", file=sys.stderr)
        return 1

    print(json.dumps({
        "ok": True,
        "written": len(written),
        "memory_log": str(Path(memory_log).expanduser().resolve()),
        "index": str(Path(index_path).expanduser().resolve()),
        "event_ids": [event["event_id"] for event in written],
    }, indent=2))
    return 0


def _load_events(spec: str) -> list:
    if spec == "-":
        raw = sys.stdin.read()
    else:
        raw = Path(spec).read_text(encoding="utf-8")
    data = json.loads(raw)
    if isinstance(data, dict) and "events" in data:
        data = data["events"]
    if not isinstance(data, list):
        raise SchemaError("events must be a JSON list")
    return data


if __name__ == "__main__":
    raise SystemExit(main())
