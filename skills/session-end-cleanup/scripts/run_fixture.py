#!/usr/bin/env python3
"""Session-end cleanup eval/dogfood runner."""

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
from shared.queue import write_queue  # noqa: E402
from shared.trash import move_to_trash  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    result = plan(fixture, workspace)
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    (out / "proposals.json").write_text(
        json.dumps({"trash": result["proposals"]}, indent=2) + "\n", encoding="utf-8"
    )
    write_queue(out / "decide-later.json", result["decide_later"])
    (out / "memory.jsonl").write_text("", encoding="utf-8")

    consent = list(fixture.get("consent") or [])
    protected = list(fixture.get("protected") or [])
    for rel in result["trash"]:
        move_to_trash(workspace, rel, consent=consent, protected=protected)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    args = parser.parse_args(argv)
    run(args.workspace, json.loads(args.fixture.read_text(encoding="utf-8")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
