---
name: trace-session-end
description: Use without being asked when a session is ending and it left a pytest cache, a dist directory, or a scratch file. Propose Trash. Move a path only when that exact path was already approved. Do not delete from a hook.
---

# Trace — session-end cleanup

Leave the work surface tidy while session context is fresh.

## When to use

- End of a coding turn/session that created temporary files
- Before walking away from pytest caches, dist/, scratch, or similar

## Steps

1. Nudge and ask before any removal. Propose disposable paths. Do not Trash without an exact yes.
2. Skip the question only for an exact path the user already approved in this session (or recorded consent).
3. Protected paths, secrets, dirty/untracked source, in-use locks, and shared stores are never proposed as selected removals. Shared/unknown → Decide-later.
4. Move consented filesystem paths through the shared Trash helper (eval: `trace-out/trash/`). Never `rm`. Never empty Trash.
5. Write proposals to `trace-out/proposals.json` in evals; in dogfood, show proposals to the user and record outcomes via the memory writer.

## Safety

- Proposal ≠ deletion.
- Fingerprint/identity must still match at move time (app Execute will re-check; skills only move exact consented paths that still exist).
- Defaults stay conservative.
