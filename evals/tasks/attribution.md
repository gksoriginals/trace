# Eval task: attribution

This is an eval instruction, not the Trace skill. Do not delete or move project files.

Each artifact has no creator yet. Run a deep attribution pass. Use only the evidence files and the evidence catalog in the fixture. The allowed sources are git history, file timestamps, agent session logs, transcripts, package and lock metadata, and the tool's own manifests. A directory name, a familiar cache path, or a nearby lockfile that does not name this file is not a source.

When the evidence supports a creator, record it. `verified` means a source states that this agent wrote this path. `inferred` means the source supports the creator without stating the write, such as a timestamp that lines up with a session which names the path, or lock metadata that implies the install. Cite the evidence ids you used. Do not cite an id that is not in the catalog.

When every source has been checked and the creator is still unknown, record creator `unknown`, label `unattributed`, and `counts: false`. Cite the evidence you checked. Do not guess an agent from the path.

A known human creator is recorded as `user` and does not count toward the agent-created ratio.

Append one JSON object per line to `trace-out/memory.jsonl`. Each event needs schema_version 1, event_id, event_type `artifact`, what (id, kind, location), why, claim, agent (harness, session_id), project (id, consumers), created (at with a timezone, source), can_go_when, evidence_ids, correction_of, and attribution:

- `source`: `git`, `mtime`, `session_log`, `transcript`, `package_lock`, `tool_manifest`, or `none`
- `label`: `verified`, `inferred`, or `unattributed`
- `counts`: true only for an agent creator

`claim` is `verified` or `inferred` when that is the label. For `unattributed`, `claim` is `observed`.

Write `trace-out/proposals.json` as `{"trash": []}` and `trace-out/decide-later.json` as `{"items": []}`.
