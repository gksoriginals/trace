# Trace

Native macOS storage hygiene for coding agents. **Skills** do everyday work inside Cursor/Codex (or via app-composed prompts). The **app** shows Decide-later + insights, Ask Trace, and on-demand Run → Actions → Execute.

## Try it

```bash
./skills/install.sh --project ~/path/to/a-project
./skills/install.sh --uninstall --project ~/path/to/a-project
./skills/install.sh --opt-out --project ~/path/to/a-project

cd app && brew install xcodegen && xcodegen generate && open Trace.xcodeproj
```

That install writes the three skills, one removable project rule (`AGENTS.md`, `.cursor/rules/trace.mdc`, `CLAUDE.md`), and stop/session-end hooks that only enqueue. The bundles in `plugins/` are the per-harness packages. There is no MCP server and no menu bar companion. See [ADR-0014](docs/adr/0014-v1-install-unit.md).

Prove skills:

```bash
python3 evals/run.py --agent skill   # 48/48 test cases + calibration
```

## Two skill modes ([ADR-0007](docs/adr/0007-markdown-memory-and-skill-invocation.md))

1. **In-session** — installed skills while you code  
2. **Composed prompt** — app sends skill + params + inputs to a Cursor/Codex instance  

## Docs

[PRD](docs/prd.md) · [Design](docs/design.md) · [Engineering](docs/engineering.md) · [Evals](docs/evals.md) · [Dogfood plan](docs/dogfood-plan.md) · [Skills](skills/README.md) · [App](app/README.md)

## Safety

Trash only · never-delete list · fingerprint re-check · conservative defaults · no Trace token caps  
