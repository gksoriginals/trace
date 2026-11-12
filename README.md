# Trace

Trace is a **native macOS app** for storage hygiene around coding agents. Skills do everyday cleanup inside Cursor and Codex; the app shows what happened, Decide-later doubts, and (later) deeper runs.

Nothing else on your Mac is in scope — project work storage and shared caches only.

## Try on your Mac (dogfood)

**Requires macOS 14+.**

```bash
git clone <this-repo> && cd trace

# 1) Install skills into Cursor/Codex skill folders
./skills/install.sh --project ~/path/to/a/coding-project

# 2) Build the native app
cd app
brew install xcodegen   # once
xcodegen generate
open Trace.xcodeproj    # Run (⌘R) on My Mac
```

Use Cursor or Codex in that project (skills nudge before installs / at session end / when recording memory). Open **Trace** Home — Decide-later and project insights read `~/.trace/index.json` and each project’s `.trace/` files. No model call on open. **Execute is not in this build** (M2).

Prove skills locally without the app:

```bash
python3 evals/run.py --agent skill          # M0 skills, 32/32 test cases
```

## How it works

1. **Hygienic setup** — before an install, ask, prefer healthy practice, avoid needless copies, record the decision.
2. **Session-end cleanup** — propose leftovers; Trash only exact consented paths; queue doubts.
3. **Memory writer** — append version-1 events to `<project>/.trace/memory.jsonl` and update `~/.trace/index.json`.
4. **Decide later** — durable queue when a decision is unclear.
5. **Trace.app** — Setup, Home, memory-only Ask (⌘K). Run/Execute later.

## Docs

- [Dogfood plan (phases)](docs/dogfood-plan.md)
- [Product requirements](docs/prd.md)
- [Design & UX](docs/design.md)
- [Engineering](docs/engineering.md)
- [Evals](docs/evals.md)
- [App build](app/README.md)
- [Skills](skills/README.md)

## Safety defaults

- Trash only — never permanent delete from Trace.
- Never-delete list respected.
- Fingerprint re-check at confirm time (Execute / M2).
- Conservative defaults; ask before cleanup/install unless that exact item was already approved.
