---
name: trace-prepare-home
description: Read Trace index/memory/Decide-later markdown and write Home insight cards. Use at session end or when Trace Refresh asks. Marks done notes; does not Trash.
---

# Trace — Prepare Home

Turn project memory into readable Home cards. The Trace app only **renders** the files you write; it does not invent card prose.

## When to use

- End of a coding session after memory/cleanup skills ran
- When the Trace app Refresh insights composes this skill into a harness prompt

## Inputs

- `index_path` — usually `~/.trace/index.md`
- `memory_dir` — `<project>/.trace/memory/`
- `decide_later_path` — `<project>/.trace/decide-later.md`
- `insights_path` — `<project>/.trace/insights.md`
- Optional retention days for archiving `status: done` notes

## Steps

1. Read memory notes (YAML frontmatter = firm v1 fields; body = why).
2. Read Decide-later; keep open/planned/deferred visible.
3. Write `insights.md` with short cards: setup changes, cleanup outcomes, kept/deferred decisions, coverage attention. Label origin as skill / app-run / user when known.
4. Set `status: done` on notes that are no longer needed for Home; archive or delete done notes only when retention says so. **Never delete Decide-later rows for age.**
5. Do not move files to Trash from this skill.

## Safety

- Read/write only under `.trace/` and the index path.
- No secrets in insight cards.
