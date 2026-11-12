# ADR-0005: Dogfood ships complete loops — skills then native app

- **Status:** accepted (Execute / agent-Ask deferral superseded by [ADR-0006](0006-full-m0-m2-cut.md))
- **Date:** 2026-11-11
- **Deciders:** Gopi

## Context

M0 in [PRD §10](../prd.md) is skills + Decide-later. M1 adds the **native macOS app** (Setup, Home, memory-only Ask). Building shared schemas alone, or skills with no app you can open, leaves nothing that matches the product: Trace is a Mac app that supervises skills. Each implementation phase must close a loop and leave something dogfoodable.

## Decision

Ship dogfood as complete loops. Skills first, then the native app shell. No phase is “foundation only.”

**M0 — skills**

| Phase | Product loop / artifact | Eval gate |
| --- | --- | --- |
| **1 — Record** | Session → memory writer → `<project>/.trace/memory.jsonl` + `~/.trace/index.json` | `memory_writer` (+ incomplete/secret calibration) |
| **2 — Doubt** | Doubt → `<project>/.trace/decide-later.json` | `decide_later` (+ queue-missing calibration) |
| **3 — Cleanup** | Leftovers → ask → propose / Trash on exact consent / queue on doubt | `session_end` (+ consent/trash/protected calibrations) |
| **4 — Prevent** | About to install → ask → checklist → approved setup recorded | `hygienic_setup` (+ duplicate-copy calibration) |

**M1 dogfood — native app**

| Phase | Product loop / artifact | Gate |
| --- | --- | --- |
| **5 — Home shell** | Launch Trace.app → read local index/logs/queue → Decide-later + insights | Manual dogfood + reader tests; no model call; no Execute |
| **6 — Setup** | Stepper → install skills whole-agent + roots/guardrails → Save | Manual Setup; install verified on disk |
| **7 — Memory-only Ask** | ⌘K → local retrieval → cited answer | Ask fixtures when wired; no agent tier |

Evals gate skill phases. The stub is not the product number. App phases are gated by buildability on macOS 14 and observable local reads. Ask Trace agent tier, Run, and Execute stay out until M2 so Home never shows working cleanup controls that do not work.

Shared schemas and atomic IO land with the first phase that needs them. Install stays [ADR-0004](0004-skills-not-a-plugin.md).

**Phase done when:** the artifact exists in dogfood shape, that phase’s gate is green, safety misses are zero where evals apply, and the report or build notes are kept with the change.

## Consequences

Dogfood is skills **plus** a native app you can open. Skills remain usable with the app closed. Home is useful offline from skill-written files. The detailed checklist lives in [dogfood-plan.md](../dogfood-plan.md).

## What would change it

Evidence that Home without Setup cannot install skills for dogfood (merge 5+6). Evidence that memory without Decide-later is useless (merge 1+2). A decision to tease Execute early would reopen design and safety, not this loop rule.
