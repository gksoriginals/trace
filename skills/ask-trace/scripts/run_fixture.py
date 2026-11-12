#!/usr/bin/env python3
"""Ask Trace memory-only eval runner."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from plan import answer_from_workspace  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    payload = answer_from_workspace(workspace, fixture)
    (out / "answer.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    args = parser.parse_args(argv)
    run(args.workspace, json.loads(args.fixture.read_text(encoding="utf-8")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
