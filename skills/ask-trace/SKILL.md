---
name: trace-ask-memory
description: Answer storage questions from local Trace memory only. Use when the Trace app or an eval asks a project storage question; never call a hosted model; never delete.
---

# Trace — Ask (memory only)

Read `<project>/.trace/memory.jsonl` or eval `trace-input/memory.jsonl`. Cite real event ids. If evidence is missing, say unknown. Never say a path is safe to remove. Never invent citation ids.
