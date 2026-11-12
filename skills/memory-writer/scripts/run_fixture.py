#!/usr/bin/env python3
"""Eval/dogfood entry: plan memory events from a fixture and write product + eval outputs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS_ROOT = SCRIPTS.parents[1]
sys.path.insert(0, str(SKILLS_ROOT))
sys.path.insert(0, str(SCRIPTS))

from plan import plan_events  # noqa: E402
from shared.memory import append_events  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    """Write eval outputs under trace-out/ only (graders treat other new files as failures)."""
    events = plan_events(fixture, workspace)
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    memory_eval = out / "memory.jsonl"
    if memory_eval.exists():
        memory_eval.unlink()
    append_events(memory_eval, events, redact=True)

    # Index path for dogfood demos stays outside the fixture tree via TRACE_HOME when set.
    # Evals do not require a product index write inside the workspace.
    (out / "proposals.json").write_text(json.dumps({"trash": []}, indent=2) + "\n", encoding="utf-8")
    (out / "decide-later.json").write_text(json.dumps({"items": []}, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    args = parser.parse_args(argv)
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    run(args.workspace, fixture)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
