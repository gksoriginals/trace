# ADR-0008: Full app vs menu bar

- **Status:** accepted
- **Date:** 2026-11-12
- **Deciders:** Gopi

## Context

Design S5–S14 live in the main window; S15 is the menu bar. Onboarding through Run must not be squeezed into a status-item popover. Closing the main window may leave the menu bar running; Quit ends owned work ([design.md](../design.md) §5.I).

## Decision

1. **Full app (main window)** — complete product: first-launch Setup S1–S4, Home, Decide-later detail, Ask Trace, Run Reviewing→Actions→Execute→Result→Recovery, Memory/Learnings, Settings. Default size ~1080×740. This is where onboarding → Run end to end happens.
2. **Menu bar (S15)** — short companion only: queue count, active stage / needs-reply, last truthful outcome, Open Trace (to the right context), Ask Trace (opens full Ask), Stop if working, Settings, Quit. No Setup stepper, no Actions consent, no one-click clean, no skill install from the popover.
3. **Lifecycle:** close main window → menu bar can keep running (and optional background review). Quit → stop owned agent work, checkpoint, end schedule. No login item / helper after quit.
4. **Distribution:** unsigned local **DMG** for dogfood until M2 auth/signing decisions.

## Consequences

Implement full Setup and Run in the window first. Menu bar reads the same local stores and session state but never owns consent or onboarding.

## What would change it

Evidence that users never open the main window (would reopen whether Setup can start from menu — still not full stepper in the popover).
