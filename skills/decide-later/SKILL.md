---
name: trace-decide-later
description: Queue doubtful storage decisions instead of guessing. Use when cleanup or install safety is unclear — shared consumers, unknown purpose, protected destinations, or incomplete evidence. Never deletes.
---

# Trace — Decide later

When a storage decision is doubtful, write a durable queue item. Do not delete, move, or edit project files from this skill.

## When to use

- Shared stores with unknown consumers
- Unexplained blobs
- User said keep / defer / revisit later
- Size or purpose unknown

## Steps

1. One item per doubt. Deduplicate by stable `id`; a repeat updates `evidence_ids` and `last_observed` only.
2. Version-1 fields: schema_version, id, project_id, agent, session_id, artifact_id, action, why_doubtful, bytes (null if unknown — never 0 as a stand-in), completeness, evidence_ids, would_resolve, first_observed, last_observed, status (`open` | `planned` | `deferred` | `kept` | `resolved` | `stale`).
3. Write `<project>/.trace/decide-later.json` via the shared helper, or for evals `trace-out/decide-later.json`.
4. Kept, deferred, stale, planned, and resolved rows stay in history. None of them is Trash permission. Planned is not consent.

## Safety

- Age alone never deletes.
- Queue items do not authorize removal.
