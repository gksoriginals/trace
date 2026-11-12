#!/usr/bin/env python3
"""Eval helper: write Decide-later queue via shared queue + plan (not a marketed skill)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS_ROOT = SCRIPTS.parents[1]
sys.path.insert(0, str(SKILLS_ROOT))

from shared.decide_later_plan import plan_items  # noqa: E402
from shared.queue import write_queue  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    items = plan_items(fixture, workspace)
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    write_queue(out / "decide-later.json", items)
    (out / "proposals.json").write_text(json.dumps({"trash": []}, indent=2) + "\n", encoding="utf-8")
    (out / "memory.jsonl").write_text("", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    args = parser.parse_args(argv)
    run(args.workspace, json.loads(args.fixture.read_text(encoding="utf-8")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
