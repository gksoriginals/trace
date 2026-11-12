# Dogfood plan — phase by phase

**Product:** Trace is a **native macOS 14+ app** (SwiftUI, menu bar). Skills do everyday hygiene inside Cursor/Codex; the app configures install and reviews outcomes. See [ADR-0006](adr/0006-m1-app-end-to-end.md).

Each phase closes a product loop **and** its gate.

## Skills (M0) — done

| Phase | Loop | Artifact | Gate |
| --- | --- | --- | --- |
| Record / Doubt / Cleanup / Prevent | Session → skill → local files | `.trace/memory.jsonl`, `decide-later.json`, `~/.trace/index.json` | `evals/run.py --agent skill` (32/32) |

## Native app (M1) — end-to-end

| Phase | Loop | You get | Gate |
| --- | --- | --- | --- |
| **Setup** | First launch → S1–S4 → install skills + save prefs | Skills on disk, app settings, project roots | Manual + installer dry-run; prefs round-trip test |
| **Home** | Open app → read index/logs/queue → Decide-later Keep/Defer | Home with queue + insights, no model call | Reader tests; keep/defer overrides in app store |
| **Ask** | ⌘K → memory retrieval → cited answer | Memory-only Ask | `evals/run.py --agent skill --skill ask_trace` |

**Out of M1:** Run → Actions → Execute, agent-tier Ask, signing.

## Try on your Mac

```bash
git pull
cd app && brew install xcodegen && xcodegen generate && open Trace.xcodeproj
# Run ⌘R — complete Setup (installs skills), then use Cursor/Codex in a selected project
python3 evals/run.py --agent skill
```
