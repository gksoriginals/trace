# Trace.app (native macOS)

Full PRD surfaces in the main window; menu bar is the short companion ([ADR-0008](../docs/adr/0008-full-app-vs-menubar.md)). **macOS 14+**. Prism/Ink theme, original Trace mark, agent badges (text + neutral glyphs until vendor logos are cleared).

## Install (dogfood DMG)

```bash
./scripts/package-dmg.sh
open build/dmg/Trace-dogfood.dmg
# Drag Trace → Applications, launch. Menu bar stays up; open the full window for Setup → Run.
```

## Build from source

```bash
cd app
brew install xcodegen   # once
xcodegen generate
open Trace.xcodeproj    # Run (⌘R) on My Mac
```

## Surfaces (design S1–S15)

| Surface | Where | Behavior |
| --- | --- | --- |
| Setup S1–S4 | Main window | Agents & skills, projects & categories, guardrails, Save & first run |
| Home S5 | Main window | Decide-later lane + project insights; local only on open |
| Decide later S6 | Main window | Why doubtful, Keep/Defer (local), Ask, Plan action ≠ Execute |
| Ask Trace S13 | Main window / ⌘K | Memory-first; optional agent escalation; read-only |
| Run S7–S9 | Main window | Per-project or **Run all projects**; Reviewing → Actions → Execute; selection is consent |
| Result S10 | Main window | Selected / moved / measured free-space Δ |
| Recovery S11 | Main window | Exact journaled Trash restore; no overwrite |
| Memory S12 | Main window | Facts vs inferred claims, sources |
| Settings S14 | Main window / Settings scene | Setup return, retention, appearance; no budgets |
| Menu bar S15 | Status item | Queue/status, Open Trace, Ask, Stop, Settings, Quit — never one-click clean |

Closing the main window leaves the menu bar running. Quit ends owned agent work.

## Data

- `~/.trace/index.md`
- `<project>/.trace/memory/*.md`, `decide-later.md`, `insights.md`
- App-only: `~/Library/Application Support/Trace/`

Install skills: `../skills/install.sh --project /path/to/project`
