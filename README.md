# Trace

Trace cleans up the storage that project work and coding agents leave behind, including shared caches. Nothing else on your Mac is in scope.

## How it works

Trace starts with three skills for coding agents. Each one does a single job.

- **Hygienic setup.** Before installing builds, containers, or toolchains, it looks up the cleanest way to install them, then records where everything went.
- **Session-end cleanup.** At the end of a session it proposes deleting short-lived files. Nothing is removed until you say yes.
- **Memory writer.** It logs each thing that was created: what it is, why it was made, which agent made it, for which project, and when it can be removed.

The Trace app finds your projects on its own. On a project's first run it suggests installing the skills, then starts the coding agent and runs it. Later runs work from the memory log.

## Goal

The skills clean up 70% of the storage that agents create, without needing the app, and nothing is deleted that you later regret.

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
