# agent.md

Notes for coding agents working on Trace.

## Product
Trace cleans up the storage that project work and coding agents create, including shared caches. Nothing else on the Mac is in scope. The source of truth is `docs/prd.md`.

## Priorities
1. The skills come first: hygienic setup, session-end cleanup, and the memory writer. Each skill does one job.
2. The app comes second. It finds projects, suggests installing the skills on a project's first run, then starts and runs the coding agent. Later runs use the memory log.

## Safety rules (non-negotiable)
- Move items to the Trash. Never delete permanently.
- Respect the never-delete list.
- Check the fingerprint again when the user confirms, before acting.
- Never remove anything without the user's explicit yes.
- Keep defaults conservative.

## Testing rule
- Write only skill evals and safety checks up front.
- No UI tests and no tests on internal design until that part has stayed stable.
- If two fix attempts in a row fail, stop and report back instead of patching tests.
- Treat everything outside the firm rules (safety, memory log format, two-way resumable agent sessions, evals first) as a current guess you can change freely. Record each pivot in `docs/adr/`.

## Workflow
- Keep changes small and focused, and update `docs/prd.md` when behavior changes.
- Batch your fixes: finish all the changes, push once, and run CI once.
