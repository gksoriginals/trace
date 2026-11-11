#!/usr/bin/env python3
"""Hygienic setup eval/dogfood runner."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS_ROOT = SCRIPTS.parents[1]
sys.path.insert(0, str(SKILLS_ROOT))
sys.path.insert(0, str(SCRIPTS))

from plan import plan  # noqa: E402
from shared.memory import append_events  # noqa: E402
from shared.queue import write_queue  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    result = plan(fixture, workspace)
    for rel, content in (result.get("create_files") or {}).items():
        path = workspace / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    (out / "setup.json").write_text(json.dumps(result.get("setup") or {"locations": []}, indent=2) + "\n", encoding="utf-8")
    (out / "proposals.json").write_text(json.dumps({"trash": []}, indent=2) + "\n", encoding="utf-8")
    write_queue(out / "decide-later.json", result.get("decide_later") or [])
    memory_path = out / "memory.jsonl"
    if memory_path.exists():
        memory_path.unlink()
    events = result.get("memory_events") or []
    if events:
        append_events(memory_path, events, redact=True)
    else:
        memory_path.write_text("", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    args = parser.parse_args(argv)
    run(args.workspace, json.loads(args.fixture.read_text(encoding="utf-8")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
