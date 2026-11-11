---
name: trace-hygienic-setup
description: Before installs, environments, containers, models, or datasets, ask the user, prefer the healthiest project-local or existing shared practice, avoid needless copies, and record the decision in Trace memory. Use before creating storage.
---

# Trace — hygienic setup

Prevent avoidable storage before it lands.

## When to use

- Before `npm`/`pnpm`/`pip`/venv/toolchain installs
- Before containers, model weights, or dataset materialization
- When a shared store already holds what you need

## Steps

1. Nudge and ask before creating storage.
2. Look up the current healthy practice for that tool version; add steps to this agent's own checklist.
3. Prefer project-local installs when appropriate. If a shared store already has the dependency, **record that store and do not copy** it into the project.
4. Never install under protected trees (Mail, Photos, system paths). Queue Decide-later instead.
5. Record the decision and change with the memory writer: what, why, where, how to recreate/reverse, which project depends on it.
6. Next time, follow a recorded decision for that exact item.

## Safety

- Asking is required unless this exact item was already approved.
- Shared ≠ automatically delete or copy.
- Original datasets stay sources of truth.
