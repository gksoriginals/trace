# AGENTS.md

Notes for coding agents working on Trace. Codex and Cursor read this file. The testing policy is not copied here.

## Product

Trace cleans up the storage that project work and coding agents create, including shared caches. Nothing else on the Mac is in scope. The source of truth is `docs/prd.md`.

## Priorities

1. The skills come first: hygienic setup, session-end cleanup, and the memory writer. They are portable Agent Skills that share one set of schemas, scripts, and safety rules. They install into each host's own skills folder, with a removable project rule and default enqueue-only hooks. Before a cleanup or an install, the skill asks. It may skip the question only for an exact item the user already approved. See `docs/adr/0014-v1-install-unit.md`.
2. The app comes second. Skills install for the whole agent by default, with a per-project opt-out. The app reads the project index and the per-project logs. It is the only writer of its database. A deeper run is on demand, with the agent the user picks, and it shows usage. There is no token cap.

## Safety rules (non-negotiable)

- Move items to the Trash. Never delete permanently.
- Respect the never-delete list.
- Check the fingerprint again when the user confirms, before acting.
- Never remove anything without the user's explicit yes.
- Keep defaults conservative.

## Firm rules

Treat everything outside the firm rules as a current guess you can change freely. Record each pivot in `docs/adr/`. The firm rules are safety, the memory log format, two-way resumable agent sessions, evals first, local storage with split writers, skill autonomy, whole-agent install with a per-project opt-out, no Trace token or time caps, the 70% metric with a deep attribution pass before bytes stay unknown, background work only while the app is running, local dogfood until M2, Cursor and Codex first, the model-choice rule (a Cursor pin is a preference, not a gate), the install unit in ADR-0014 (skills, rule, enqueue-only hooks, plugin bundle, no MCP), and macOS 14. The window app on main is the product shell; do not add a menu bar companion. The winning model id, file paths, and timeout numbers are guesses.

## Testing policy

Read and follow `docs/agent-policy.md`. That file is the policy. This file does not restate it. It replaces the shorter testing rule that used to live in `agent.md`.

## Workflow

- Keep changes small and focused, and update `docs/prd.md` when behavior changes.
- Batch your fixes: finish all the changes, push once, and run CI once.
