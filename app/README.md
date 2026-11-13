# Trace.app (native macOS)

Full PRD surfaces in the main window ([ADR-0012](../docs/adr/0012-no-menu-bar-companion.md): no menu bar companion). **macOS 14+**. Prism/Ink theme, original Trace mark, agent badges (text + neutral glyphs until vendor logos are cleared).

## Install (dogfood)

Replace `/Applications/Trace.app` from a Release build (preferred while iterating):

```bash
./scripts/install-app.sh
```

Or build a DMG:

```bash
./scripts/package-dmg.sh
open build/dmg/Trace-dogfood.dmg
# Drag Trace → Applications, launch.
```

## Build from source

```bash
cd app
brew install xcodegen   # once
xcodegen generate
open Trace.xcodeproj    # Run (⌘R) on My Mac
```

## Surfaces (design S1–S14)

| Surface | Where | Behavior |
| --- | --- | --- |
| Setup S1–S4 | Main window | Agents & skills (per-agent opt-in), projects & categories, guardrails, Save & first run |
| Home S5 | Main window | Decide-later lane + project insights; local only on open |
| Decide later S6 | Main window | Why doubtful, Keep/Defer (local), Ask, Plan action ≠ Execute |
| Ask Trace S13 | Main window / ⌘K | Chat-style memory-first; optional agent escalation; read-only |
| Run S7–S9 | Main window | Per-project or **Run all projects**; Reviewing → Actions → Execute; selection is consent |
| Result S10 | Main window | Selected / moved / measured free-space Δ |
| Recovery S11 | Main window | Exact journaled Trash restore; no overwrite |
| Memory S12 | Main window | Index + detail; facts vs inferred claims, sources |
| Settings S14 | Main window / Settings scene | Per-agent skills, Add agent (not re-open wizard), retention, appearance; no budgets |

Quit ends owned agent work and any optional background review. Skills still work with the app closed.

## Data

- `~/.trace/index.md`
- `<project>/.trace/memory/*.md`, `decide-later.md`, `insights.md`
- App-only: `~/Library/Application Support/Trace/`

Install skills: `../skills/install.sh --project /path/to/project`
