#!/usr/bin/env python3
"""Focused unit checks for shared skill core."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from shared.index import upsert_project
from shared.memory import append_events, read_events
from shared.queue import upsert_items, write_queue
from shared.redact import redact_text
from shared.schemas import SchemaError


class SharedCoreTests(unittest.TestCase):
    def test_redact_token(self):
        self.assertNotIn("sk-secret-token", redact_text("used sk-secret-token here"))
        self.assertIn("[redacted]", redact_text("used sk-secret-token here"))

    def test_append_and_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            log = tmp_path / "memory.jsonl"
            index = tmp_path / "index.json"
            event = {
                "schema_version": 1,
                "event_id": "e1",
                "event_type": "artifact",
                "what": {"id": "a", "kind": "build", "location": "out", "bytes": None, "completeness": "known"},
                "why": "test with sk-secret-token",
                "claim": "observed",
                "agent": {"harness": "codex", "session_id": "s1"},
                "project": {"id": "p1", "consumers": ["p1"]},
                "created": {"at": "2026-11-11T10:00:00+05:30", "source": "observed"},
                "can_go_when": "when done",
                "evidence_ids": ["t1"],
                "correction_of": None,
            }
            written = append_events(log, [event])
            self.assertNotIn("sk-secret-token", written[0]["why"])
            upsert_project(index, project_id="p1", memory_log=log, roots=[str(tmp_path)])
            doc = json.loads(index.read_text())
            self.assertEqual(doc["projects"][0]["id"], "p1")
            self.assertEqual(len(read_events(log)), 1)

    def test_queue_dedupe(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "q.json"
            item = {
                "schema_version": 1,
                "id": "dl1",
                "project_id": "p",
                "agent": "codex",
                "session_id": "s",
                "artifact_id": "a",
                "action": "remove",
                "why_doubtful": "unknown",
                "bytes": None,
                "completeness": "unknown",
                "evidence_ids": ["t1"],
                "would_resolve": "list consumers",
                "first_observed": "2026-11-11T10:00:00+05:30",
                "last_observed": "2026-11-11T10:00:00+05:30",
                "status": "open",
            }
            write_queue(path, [item])
            item2 = dict(item)
            item2["last_observed"] = "2026-11-11T10:05:00+05:30"
            item2["evidence_ids"] = ["t2"]
            items = upsert_items(path, [item2])
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0]["last_observed"], "2026-11-11T10:05:00+05:30")
            self.assertEqual(items[0]["evidence_ids"], ["t1", "t2"])

    def test_reject_bad_event(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "m.jsonl"
            with self.assertRaises(SchemaError):
                append_events(log, [{"schema_version": 1}])


if __name__ == "__main__":
    unittest.main()
