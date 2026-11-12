# Dogfood plan — phase by phase

**Product:** Trace is a **native macOS 14+ app** (SwiftUI, menu bar). Skills do everyday hygiene inside Cursor/Codex; the app is the review surface. You should be able to install skills **and** open Trace on your Mac.

Each phase closes a product loop **and** its gate. No phase ships only scaffolding.

## Skills first (M0)

| Phase | Loop | On disk / in agent | Gate | Try on your Mac |
| --- | --- | --- | --- | --- |
| **1 — Record** | Session created storage → memory writer | `<project>/.trace/memory.jsonl`, `~/.trace/index.json` | `evals/run.py --agent skill --skill memory_writer` | Agent records what it created |
| **2 — Doubt** | Uncertain decision → Decide-later | `<project>/.trace/decide-later.json` | `--skill decide_later` | Doubtful items queue instead of guessing |
| **3 — Cleanup** | Leftovers → ask → propose / Trash on exact yes | proposals + Trash via native-safe boundary | `--skill session_end` | Session-end skill proposes; only exact consent moves |
| **4 — Prevent** | About to install → ask → record setup | setup locations + decision events | `--skill hygienic_setup` | Hygienic setup avoids needless copies |

Skills work with the app closed. Install copies them into the host skills folders and adds one project instruction line ([ADR-0004](adr/0004-skills-not-a-plugin.md)).

## Native app next (M1 dogfood shell)

| Phase | Loop | You open on the Mac | Gate | Try on your Mac |
| --- | --- | --- | --- | --- |
| **5 — Home shell** | App launch → read local index/logs/queue → Decide-later + project insights | Trace.app (menu bar), Home only, **no model call**, **no Execute** | Manual: open app, see queue/insights from real skill files; unit tests for readers | `open` Trace; Home shows what skills wrote |
| **6 — Setup** | Onboarding → install skills whole-agent + project roots/guardrails → Save | Setup stepper; writes skills + config; first run is read-only inspection | Manual Setup path; skill install verified | First-launch Setup installs skills and selects projects |
| **7 — Memory-only Ask** | ⌘K → retrieve from local memory → cited answer | Ask Trace panel, memory tier only | Ask fixtures when wired; no agent escalation yet | Ask a project question without spending agent quota |

Execute / Run / agent-tier Ask stay **M2** and are disabled or absent in this dogfood build so we never tease cleanup controls that do not work ([design.md](design.md)).

## How you try it

```bash
# on your Mac
git pull
./skills/install.sh --project ~/path/to/a/project
open Package.swift   # or Xcode project under app/ — build & run Trace
# use Cursor/Codex in that project; open Trace Home to see Decide-later + insights
```

Minimum system: **macOS 14**. Unsigned local build is fine until M2 ([ADR-0002](adr/0002-locked-product-decisions.md)).

## Out of this dogfood

- Run → Actions → Execute (M2)
- Agent-escalated Ask (M2)
- Claude / Gemini adapters
- Signing / notarization / public name
- Optional hooks (off by default)

## Done for “a version I can try”

1. Four skills + shared core + `skills/install.sh`
2. Native SwiftUI app that builds in Xcode on your Mac
3. Home reads `~/.trace/index.json` and per-project logs/queues with no provider call
4. M0 skill evals green on `--agent skill`
5. Short README: install skills, build app, dogfood
