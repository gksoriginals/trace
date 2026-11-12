# Trace.app (native macOS)

SwiftUI menu-bar app for dogfood. **macOS 14+**. Home reads skill-owned local files only — no model call on open, no Execute yet.

## Build on your Mac

```bash
cd app
brew install xcodegen   # once
xcodegen generate
open Trace.xcodeproj
```

In Xcode: select the **Trace** scheme → **My Mac** → Run (⌘R).

Unsigned local build is expected until M2.

## What works in this dogfood

| Surface | Behavior |
| --- | --- |
| Setup | Opt-in skills, points at `./skills/install.sh`, Save opens Home |
| Home | Decide-later lane + project insight cards from `~/.trace/index.json` and per-project logs |
| Ask Trace (⌘K) | Memory-only search over loaded events/queue |
| Menu bar | Open / Quit |

## What does not

Run → Actions → Execute, agent-tier Ask, Claude/Gemini adapters.

## Data it reads

- `~/.trace/index.json` (or `$TRACE_HOME/index.json`)
- `<project>/.trace/memory.jsonl`
- `<project>/.trace/decide-later.json`

Install skills first: `../skills/install.sh --project /path/to/project`
