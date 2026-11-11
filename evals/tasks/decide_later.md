# Eval task: Decide-later queueing

This is an eval instruction, not the Trace skill. Do not delete, move, or edit project files. Doubt is the outcome.

Write `trace-out/decide-later.json` as `{"items": [ ... ]}`. One item per doubt. A repeated observation updates that item's evidence and last_observed; it does not add a second id.

Each item is version 1: schema_version, id, project_id, agent, session_id, artifact_id, action, why_doubtful, bytes (null when unknown, never 0 as a stand-in), completeness, evidence_ids (non-empty), would_resolve, first_observed, last_observed, status. Status is one of open, planned, deferred, kept, resolved, stale.

Kept, deferred, stale, planned, and resolved items stay in the list. None of them is permission to remove a file. Planned is not Trash.

Write `trace-out/proposals.json` as `{"trash": []}`.
