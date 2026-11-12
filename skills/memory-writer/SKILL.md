---
name: trace-memory-writer
description: Record storage Trace cares about — artifacts, setup changes, cleanup outcomes, coverage receipts, and decisions — into the project's local memory log. Use during or at the end of a turn when the session created, kept, or cleaned storage; never to delete files.
---

# Trace — memory writer

Preserve provenance for project-work storage. Do **not** delete or move files. Do **not** invent creators. Separate observed / inferred / verified.

## When to use

- After creating builds, caches, environments, containers, models, or datasets
- After a setup change you want to recreate later
- After a cleanup outcome or coverage receipt
- When correcting an earlier memory event (append a new event; leave the old one)

## Steps

1. Identify each artifact or event from this session (path or tool-native id).
2. Draft version-1 JSON events with firm fields: `schema_version` 1, `event_id`, `event_type`, `what` (id, kind, location), `why`, `claim`, `agent` (harness, session_id), `project` (id, consumers), `created` (at with timezone, source), `can_go_when`, `evidence_ids`, `correction_of` (null if not a correction).
3. Redact secrets from `why` and recipes. Never copy tokens or passwords into the log.
4. Append via the shared recorder (preferred):

```bash
python3 "$TRACE_SKILLS/memory-writer/scripts/record.py" \
  --project-root . --project-id "<project-id>" \
  --events events.json
```

Default log: `<project>/.trace/memory.jsonl`. Index: `~/.trace/index.json` (or `$TRACE_HOME/index.json`).

5. For shared stores, list known consumers; if any consumer is unknown, say so and use `claim: inferred`. Never call it unused.
6. `can_go_when` is a condition (task done, no consumers), never “it is old.”
7. Original datasets and source checkouts are sources of truth, not disposable because of age.

## Safety

- Never permanently delete. Never Trash from this skill.
- Protected paths stay untouched.
- Memory is advisory; it does not authorize cleanup.
