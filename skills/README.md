# Trace skills (M0)

Portable Agent Skills shared by Cursor and Codex. The native Mac app reads what they write; it is not required for them to run.

| Skill | Folder | Writes |
| --- | --- | --- |
| Memory writer | `memory-writer/` | `<project>/.trace/memory.jsonl`, `~/.trace/index.json` |
| Decide later | `decide-later/` | `<project>/.trace/decide-later.json` |
| Session-end cleanup | `session-end-cleanup/` | proposals + Trash (exact consent) |
| Hygienic setup | `hygienic-setup/` | setup locations + memory/queue |

Shared schemas and IO: `shared/`.

## Install

```bash
./skills/install.sh
./skills/install.sh --project ~/code/my-project
```

## Prove on this machine

```bash
python3 evals/run.py --agent skill --skill memory_writer
python3 evals/run.py --agent skill   # all M0 skills
```
