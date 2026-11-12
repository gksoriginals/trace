#!/usr/bin/env python3
"""Eval helper: deep attribution pass (not a marketed skill)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SKILLS_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SKILLS_ROOT))

from shared.attribution import attribute_artifacts  # noqa: E402
from shared.memory import append_events  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    events = attribute_artifacts(fixture, workspace)
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    append_events(out / "memory.jsonl", events)
    (out / "proposals.json").write_text(json.dumps({"trash": []}, indent=2) + "\n", encoding="utf-8")
    (out / "decide-later.json").write_text(json.dumps({"items": []}, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    args = parser.parse_args(argv)
    run(args.workspace, json.loads(args.fixture.read_text(encoding="utf-8")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
