# Trace

Trace cleans up the storage that project work and coding agents leave behind, including shared caches. Nothing else on your Mac is in scope.

## How it works

Trace starts with three skills for coding agents. Each one does a single job.

- **Hygienic setup.** Before an install it asks, looks up the healthiest way to do it, adds the steps to the agent's own checklist, then records where everything went and what you decided.
- **Session-end cleanup.** It asks before removing short-lived files. It skips the question only for an exact item you already approved.
- **Memory writer.** It logs each thing that was created: what it is, why it was made, which agent made it, for which project, when it can be removed, and the decisions you made.

Skills install for the whole agent by default. A project can opt out. The first agents are Cursor and Codex. The app reads each project's local memory. On demand it can run a deeper pass with the agent you pick. It shows what that pass used. It does not set a token cap.

## Goal

Remove 70% of the bytes in artifacts an agent created, within 30 days of creation, and delete nothing you later regret. Shared caches count once. Free space is shown separately and is not this number.

## Safety defaults

These are carried over from Shed:
- Items go to the Trash. Nothing is deleted permanently.
- Paths on the never-delete list are never touched.
- Before deleting, Trace checks each item's fingerprint again when you confirm.
- Defaults are conservative.

## Status

Early.

## Docs

- [Product requirements](docs/prd.md)
- [Design & UX specification](docs/design.md)
- [Engineering direction](docs/engineering.md)
- [Evals](docs/evals.md)
- [Decision records](docs/adr/)
