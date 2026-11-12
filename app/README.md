# Trace.app — native macOS (M1 end-to-end)

SwiftUI menu-bar app for **macOS 14+**. Completes Setup → Home → memory-only Ask. **No Execute** (M2).

## Build

```bash
cd app
brew install xcodegen   # once
xcodegen generate
open Trace.xcodeproj
```

Scheme **Trace** → **My Mac** → Run (⌘R). Unsigned local dogfood is expected.

On first launch, complete Setup:

1. **Agents & skills** — detect Cursor/Codex; opt in; choose the repo `skills/` folder  
2. **Projects** — add project roots; categories (inspect, not delete)  
3. **Guardrails** — preferred agent, never-touch, notifications off by default  
4. **Save & first run** — writes app prefs and runs `skills/install.sh` (never grants Trash)

Then use Cursor/Codex in those projects. Refresh Home to see Decide-later and insights from `~/.trace/`.

## Surfaces (M1)

| Surface | Behavior |
| --- | --- |
| Setup S1–S4 | Real skill install + preferences |
| Home | Decide-later + project insights; no model call |
| Decide-later detail | Keep / Defer (app-store overrides) / Ask |
| Ask Trace (⌘K) | Memory-only cited answers |
| Memory | Read skill logs |
| Menu bar | Open / Ask / Setup / Quit |

## Data

- **Skills write:** `~/.trace/index.json`, `<project>/.trace/memory.jsonl`, `decide-later.json`  
- **App writes:** `~/Library/Application Support/Trace/preferences.json` (settings + Keep/Defer overrides)

## Evals

```bash
python3 evals/run.py --agent skill --skill ask_trace
python3 evals/run.py --agent skill
```
