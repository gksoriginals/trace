# ADR-0001: Shed to Trace

- **Status:** accepted
- **Date:** 2026-11-11
- **Deciders:** Gopi

The product choices this record left open are locked in [ADR-0002](0002-locked-product-decisions.md). This record stays as the Shed split.

## Context

Shed was a Mac cleaner that tried to understand a whole disk, then delete with an agent. Two lessons from using it shaped the next product. A full run was the only way to do the work, and it burned too many tokens. The app crashed in ways Gopi associated with having no two-way communication with the coding agent: a process was started and the UI was left guessing. Trace is a new product in a new repository, not a phase of Shed. This environment could not open `gksoriginals/shed` (the GitHub API returned 404), so this record uses the lessons PRD v0.2 kept after reading Shed's PRD, UX, implementation ledger, and README. It does not copy Shed's code, tests, or release gates.

## Decision

Build Trace as storage hygiene for project work and coding agents, shared caches included, and nothing else on the Mac.

Keep the safety lessons: provenance before guesses, the three questions (recreation cost, current dependents, source of truth), the never-delete list, a fingerprint check at confirm time, Trash with an explicit restore path, conservative defaults, and honest byte accounting.

Move everyday work into skills that run inside the coding agent. The app shows what happened, holds the Decide-later queue, and runs a deeper pass only when asked. That pass uses a persistent, resumable, two-way session. Home reads local records and does not call a model to render.

Leave behind Shed's whole-disk second pass, whole-Mac categories, system-junk scope, treemap ambitions, Run-as-the-home-screen, mandatory Full Disk Access onboarding, and the hard scan benchmarks and test suite. Do not port them "just in case."

## Consequences

The first thing to build is the skills, their memory format, and the evals that score outcomes. The app comes after, and its agent path has to speak a real session protocol on day one. Architecture that a later ADR has not locked stays a guess. ADR-0002 rejected Trace-side token caps.

Token cost and crash recovery are design constraints, not slogans. Small scoped calls, a memory-first answer path, and a session that can be interrupted, resumed, and killed with its process group are part of the product.

## What would change it

A dogfood result showing that in-session skills cannot see the storage that matters, or that a two-way session still cannot be cancelled cleanly on the agents Gopi actually runs. Either one reopens the split between skills and the app. A measured regret would reopen a safety rule. A wish to clean Mail, Photos, or system junk would be a different product.
