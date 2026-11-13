# ADR-0010: Report-only items use `trace-out/report.json`

- **Status:** accepted
- **Date:** 2026-11-13
- **Deciders:** Gopi

## Context

PRD §8.5 keeps tool-native removals that cannot be restored via Trash (containers, volumes, image prune, and similar) **report-only** until a separate recovery/action design exists. The Ally cleanup field notes needed an eval (`se-dev-11`) for a never-started container: proposals must stay empty, and the finding must still be written down.

Two shapes were considered:

1. A new `trace-out/report.json` channel.
2. Reuse Decide-later with status `kept`.

Decide-later is the durable **doubt** queue (`open` / `planned` / `deferred` / `kept` / `resolved` / `stale`). `kept` means a doubtful item was deliberately left alone. Policy-forbidden or irreversible tool-native findings are not doubt; stuffing them into the queue would inflate Home’s top list and blur “user kept this” with “Trace must not act.”

## Decision

Report-only findings are written to **`trace-out/report.json`**. They are not Trash proposals and not Decide-later items.

Each report item carries at least: schema version, stable id, kind (e.g. `container`), subject identity, why it is report-only, `actionable: false`, and optional tool/context/state/bytes/evidence. Skills may explain space and state; they must not turn a report item into Execute without a later, separately approved recovery design.

Home’s Decide-later queue stays for uncertainty. Insights / Run review may surface report items; they do not compete with open doubts.

## Consequences

- Eval harness grades `report_ids` (and related fields) from `trace-out/report.json`.
- Session-end (and later Run) can record never-started containers, reclaimable-vs-selected accounting notes, and other §8.5 findings without false “kept” queue rows.
- When a recovery design for a tool-native action is approved, that class may graduate from report-only to proposable/Execute; the report channel remains for anything still irreversible or out of scope.

## What would change it

A dogfood finding that report items are invisible in practice and users never see irreversible waste — then the UI surface for reports needs work, not a merge into Decide-later. Or an approved container recovery design that makes a class of items actionable.
