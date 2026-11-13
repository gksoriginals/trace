# Dogfood plan — harness-native E2E

Skills run **in-session** or via **app-composed prompts** to Cursor/Codex ([ADR-0007](adr/0007-markdown-memory-and-skill-invocation.md)). Full cut through M2 ([ADR-0006](adr/0006-full-m0-m2-cut.md)).

## Skills (M0)

| Phase | Loop | Gate |
| --- | --- | --- |
| Record / Doubt / Cleanup / Prevent | Three skills + Decide-later queue + prepare-home | `evals/run.py --agent skill` |
| Install | Host skills folders + project line | `./skills/install.sh --project …` |

Markdown: `~/.trace/index.md`, `<project>/.trace/memory/*.md`, `decide-later.md`, `insights.md`.

## App (M1–M2)

| Phase | Loop |
| --- | --- |
| Setup | 4-step stepper; install skills; no budgets |
| Home | File-only Decide-later + insights; Refresh = compose prepare-home |
| Ask | Full-corpus memory-first; agent tier = task+params+inputs (harness tools) |
| Run | Per-project or all permitted; Reviewing → Actions → Execute (Trash + journal) |
| Background | Optional; only while Trace app running; never Execute; no menu bar |

## Try

```bash
./skills/install.sh --project ~/code/my-project
./scripts/package-dmg.sh && open build/dmg/Trace-dogfood.dmg
# Or from source: cd app && brew install xcodegen && xcodegen generate && open Trace.xcodeproj
python3 evals/run.py --agent skill
```

Full Setup → Home → Ask → Run lives in the main window. There is no menu bar companion ([ADR-0012](adr/0012-no-menu-bar-companion.md)).
