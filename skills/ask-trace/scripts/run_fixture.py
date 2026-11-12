#!/usr/bin/env python3
"""Eval helper: memory-only Ask Trace (app surface, not a marketed skill)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SKILLS_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SKILLS_ROOT))

from shared.ask_memory import answer_from_memory, write_answer  # noqa: E402
from shared.memory import read_events  # noqa: E402


def run(workspace: Path, fixture: dict) -> None:
    memory_path = workspace / "trace-input" / "memory.jsonl"
    events = read_events(memory_path) if memory_path.is_file() else []
    turns = (fixture.get("session") or {}).get("turns") or []
    question = next((t.get("text") for t in turns if t.get("role") == "user"), fixture.get("notes") or "")
    answer = answer_from_memory(question, events=events)
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    write_answer(out / "answer.json", {
        "text": answer["text"],
        "citations": answer["citations"],
        "unknown": answer["unknown"],
        "tier": "memory",
    })
    (out / "proposals.json").write_text(json.dumps({"trash": []}, indent=2) + "\n", encoding="utf-8")
    (out / "decide-later.json").write_text(json.dumps({"items": []}, indent=2) + "\n", encoding="utf-8")
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
