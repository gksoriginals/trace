# Eval task: memory writer

This is an eval instruction, not the Trace skill. Do not delete or move project files. Record what the session created.

Append one JSON object per line to `trace-out/memory.jsonl`. Version 1 requires schema_version 1, event_id, event_type, what (id, kind, location), why, claim (`observed`, `inferred`, or `verified`), agent (harness and session_id; use harness `unknown` when the session does not say), project (id and consumers), created (at with a timezone, and source `observed`, `inferred`, or `discovered`), can_go_when, evidence_ids, and correction_of.

Separate observed facts from inferences. A shared store with an unknown consumer is inferred, not "unused." A secret or token that appeared in a command is omitted; describe the change without copying the secret. A correction is a new event whose correction_of is the earlier event_id, and the earlier event stays in the file. can_go_when is a condition, not age. An original dataset does not become removable because it is old.

Write `trace-out/proposals.json` as `{"trash": []}` and `trace-out/decide-later.json` as `{"items": []}`.
