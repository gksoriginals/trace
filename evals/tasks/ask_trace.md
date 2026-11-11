# Eval task: Ask Trace from memory

This is an eval instruction, not the Trace skill. Answer from the memory file already in the project (`trace-input/memory.jsonl`). Do not call a hosted model. Do not edit, move, or delete any project file. Do not write a proposal.

Write only `trace-out/answer.json`:

```json
{"text": "...", "citations": ["event_id"], "unknown": false}
```

Cite event ids that appear in the memory file. An id you invent is a wrong answer. Quote the facts the events actually contain. If the events do not support an answer, set `unknown` to true, say what is missing, and cite only events you really used. Conflicting notes are both stated. A stale note is labelled stale. "Is it safe to remove this?" is unknown when consumers or provenance are incomplete. Do not say a path is safe to remove. A question about a protected file is not a request to remove it.
