# ADR-0006: M1 app is end-to-end Setup → Home → Ask (no Execute)

- **Status:** accepted
- **Date:** 2026-11-12
- **Deciders:** Gopi

## Context

The first dogfood PR shipped skills plus a thin Home shell. That is not the product loop in [design.md](../design.md): first launch Setup installs skills and saves config, Home resolves Decide-later and shows insights from local evidence, Ask answers from memory. Execute remains M2 so we never enable Move-to-Trash in the app before the consent boundary exists.

## Decision

Rewrite the native app to complete **M1 end-to-end**:

1. **Setup S1–S4** — detect Cursor/Codex CLIs, opt-in skills, whole-agent install via `skills/install.sh`, project roots + categories, guardrails (never-touch, preferred agent, notifications off by default), Save (and optional Save without first-run). No budgets. No Execute consent.
2. **Home S5–S6** — Decide-later first; Keep/Defer as local app-db overrides merged onto the skill-written queue; project insight cards with Skill origin; coverage unknown labelled unknown. Opening Home starts no model call.
3. **Ask S13 memory-only** — one surface, scope chips, citations to event ids; escalate UI offers M2 later and does not call an agent in M1.
4. **Settings** — return to Setup steps. Menu bar opens Home / Ask / Quit.

App preferences and queue status overrides live in the app-only store under Application Support. Skills remain the writers of per-project `memory.jsonl`, `decide-later.json`, and `~/.trace/index.json`.

Skill folder splits wait until after this e2e loop and evals; do not reshape skills in the same change.

## Consequences

Dogfood on a Mac is: install/build app → Setup saves and copies skills → use Cursor/Codex → Home/Ask show local evidence. Ask eval fixtures run against a shared retrieval script that mirrors the app’s memory-only rules. Run/Execute stay absent or disabled.

## What would change it

Dogfood showing Keep/Defer must write the skill queue file directly (would reopen split writers). A need to ship Execute before M2 (would reopen safety and design).
