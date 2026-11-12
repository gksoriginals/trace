# Trace skills

Portable Agent Skills for Cursor and Codex. The Mac app reads what they write.

## Invocation (ADR-0007)

1. **In-session** — installed in the host skills folder; used while you code.
2. **Composed prompt** — Trace.app sends skill `SKILL.md` + params + inputs to a Cursor ACP / Codex instance (Refresh, Run Reviewing, agent Ask).

## Product install

| Skill | Folder |
| --- | --- |
| Hygienic setup | `hygienic-setup/` |
| Session-end cleanup | `session-end-cleanup/` |
| Memory writer | `memory-writer/` |
| Prepare Home | `prepare-home/` |

Shared core: `shared/` (schemas, markdown frontmatter, safety, Trash, compose).

```bash
./skills/install.sh
./skills/install.sh --project ~/code/my-project
```

## On-disk layout

- `~/.trace/index.md`
- `<project>/.trace/memory/*.md`
- `<project>/.trace/decide-later.md`
- `<project>/.trace/insights.md`

## Prove

```bash
python3 evals/run.py --agent skill
```
