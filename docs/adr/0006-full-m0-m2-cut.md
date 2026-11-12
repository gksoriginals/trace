# ADR-0006: Full M0–M2 cut, then evals

- **Status:** accepted
- **Date:** 2026-11-12
- **Deciders:** Gopi
- **Supersedes:** ADR-0005’s deferral of Execute / agent-tier Ask from dogfood (loop discipline for skills→app remains)

## Context

ADR-0005 shipped dogfood as complete loops but kept Run → Actions → Execute and agent-tier Ask out of that build so Home would not tease cleanup that did not work. The product docs (PRD, engineering, ADR-0002/0004) already lock the full contract. Gopi chose one end-to-end cut through M2, then skill evals and refactoring, and to discard the thin dogfood SwiftUI shell.

Evals and dogfood copy had drifted: “four skills” / “five skills” while ADR-0004 locks **three** Agent Skills; Decide-later is a shared queue, Ask is an app surface, attribution is a deep pass / eval suite.

## Decision

1. Build Trace through M2 in one cut: three portable skills + shared core, native Setup/Home/memory-only Ask, Cursor ACP and Codex app-server sessions, Run Reviewing → Actions → Execute (Trash + journal), and agent-tier Ask behind memory-first + explicit scope accept.
2. Replace the dogfood `app/Trace` shell; do not preserve its incidental structure.
3. Product install installs only `hygienic-setup`, `session-end-cleanup`, and `memory-writer`, plus one project instruction line. Decide-later stays a shared queue API (eval helper scripts may remain for `--skill decide_later`). Ask Trace and attribution stay eval suites / app or Reviewing capabilities, not marketed Agent Skills.
4. After the cut builds, run `evals/run.py --agent skill` (and live cells when CLIs exist), then refactor from measured failures without weakening graders.

## Consequences

Dogfood can exercise Execute on disposable fixtures. Design still forbids enabling fake cleanup controls — Execute must be real when shown. ADR-0005’s “phase closes a loop” rule still applies inside the cut; only the “Execute stays out” clause is superseded. Packaging language in evals/dogfood docs must match the three-skill lock.

## What would change it

Evidence that shipping Execute before skill evals causes unsafe defaults on real data. A measured need to split skills after evals (allowed; not a reopen of the three-skill product contract until an ADR says so).
