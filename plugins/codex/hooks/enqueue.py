#!/usr/bin/env python3
"""Stop / session-end hook. Append one queue line and exit.

Does not scan the tree, read credential files, or delete anything.
The app or the next session drains ~/.trace/hook-queue.jsonl.
"""

from __future__ import annotations

import argparse
import json
import os
import select
import sys
from datetime import datetime, timezone
from pathlib import Path

SAFE_KEYS = ("hook_event_name", "conversation_id", "session_id", "cwd", "reason", "event")


def _read_stdin() -> dict:
    if sys.stdin.isatty():
        return {}
    ready, _, _ = select.select([sys.stdin], [], [], 0.05)
    if not ready:
        return {}
    raw = sys.stdin.read(8192)
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return {}
    if not isinstance(payload, dict):
        return {}
    return {key: payload.get(key) for key in SAFE_KEYS if payload.get(key) not in (None, "")}


def _append(path: Path, line: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(line)
        handle.flush()
        os.fsync(handle.fileno())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Enqueue a Trace hook event")
    parser.add_argument("--event", default="stop")
    parser.add_argument("--host", default=os.environ.get("TRACE_HOST", "unknown"))
    parser.add_argument("--drain", action="store_true")
    args = parser.parse_args(argv)

    home = Path(os.environ.get("TRACE_HOME", str(Path.home() / ".trace"))).expanduser()
    project = Path(os.environ.get("TRACE_PROJECT", Path.cwd())).expanduser()
    shared = home / "hook-queue.jsonl"

    if args.drain:
        if not shared.is_file():
            print("[]")
            return 0
        lines = shared.read_text(encoding="utf-8").splitlines()
        shared.unlink()
        print(json.dumps(lines))
        return 0

    meta = _read_stdin()
    record = {
        "schema_version": 1,
        "kind": "hook",
        "event": args.event,
        "host": args.host,
        "project": str(project),
        "enqueued_at": datetime.now(timezone.utc).isoformat(),
        "meta": meta,
        "note": "drain in the app or the next session; do not clean up in the hook",
    }
    line = json.dumps(record, ensure_ascii=False) + "\n"
    _append(shared, line)
    _append(project / ".trace" / "hook-queue.jsonl", line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
