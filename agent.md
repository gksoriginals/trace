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

## Testing
Don't lock in hard tests or acceptance gates up front. Add tests only once a behavior has settled.

## Workflow
- Keep changes small and focused, and update `docs/prd.md` when behavior changes.
- Batch your fixes: finish all the changes, push once, and run CI once.
