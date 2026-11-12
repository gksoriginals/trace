---
name: trace-decide-later
description: Eval/helper notes for the shared Decide-later queue. Not a marketed Agent Skill — product install does not copy this folder. The three Trace skills write the queue via shared helpers.
---

# Trace — Decide later (shared queue)

When a storage decision is doubtful, write a durable queue item. Do not delete, move, or edit project files from this helper.

Product skills call `shared.queue`. The eval suite uses `decide-later/scripts/run_fixture.py`.

## Fields (version 1)

schema_version, id, project_id, agent, session_id, artifact_id, action, why_doubtful, bytes (null if unknown — never 0 as a stand-in), completeness, evidence_ids, would_resolve, first_observed, last_observed, status (`open` | `planned` | `deferred` | `kept` | `resolved` | `stale`).

Deduplicate by stable `id`; a repeat updates `evidence_ids` and `last_observed` only. Queue items never authorize Trash.
