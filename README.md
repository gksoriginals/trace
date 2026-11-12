# Trace

Trace is a **native macOS 14+ app** for storage hygiene around coding agents. Skills do everyday work inside Cursor and Codex; the app installs those skills, shows Decide-later and insights, and answers from local memory. Cleanup **Execute** is M2.

## Try on your Mac

```bash
git clone <repo> && cd trace
cd app && brew install xcodegen && xcodegen generate && open Trace.xcodeproj
# Run ⌘R — complete Setup (points at this repo’s skills/ folder)
```

Use Cursor or Codex in a selected project. Open Trace Home (Refresh) to see local outcomes. Ask Trace with ⌘K (memory only).

```bash
python3 evals/run.py --agent skill    # M0 skills + Ask memory-only
```

## Docs

- [Dogfood plan](docs/dogfood-plan.md) · [ADR-0006 M1 app](docs/adr/0006-m1-app-end-to-end.md)
- [PRD](docs/prd.md) · [Design](docs/design.md) · [Engineering](docs/engineering.md) · [Evals](docs/evals.md)
- [App](app/README.md) · [Skills](skills/README.md)

## Safety

Trash only (when Execute exists). Never-delete list. Ask before cleanup/install unless that exact item was already approved. Conservative defaults.
