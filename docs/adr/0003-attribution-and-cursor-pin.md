# ADR-0003: Attribution before unknown, and Cursor pins are preferences

- **Status:** accepted
- **Date:** 2026-11-11
- **Deciders:** Gopi

## Context

[ADR-0002](0002-locked-product-decisions.md) locked the 70% metric and the model rule, and left two gaps. Bytes with no known creator were left out of the ratio with no attempt to find a creator. A Cursor model pin was treated as something the runtime had to honor, even though Cursor ACP can ignore it. Both are decided here. ADR-0002 stays the lock of the ten product choices. This record narrows items 4 and 9.

## Decision

**Attribution.** Bytes with no creator are not dropped on sight. The coding agent runs a deep attribution step over git history, file timestamps, agent session logs and transcripts, package and lock metadata, and the tool's own manifests. A creator it can support with evidence is recorded, with that evidence and a `verified` or `inferred` label, and those bytes count toward the 70%. A directory name is not evidence. A known human creator is recorded and does not count as agent-created. Only bytes that are still unknown after that pass stay out of the ratio, and they are reported separately, with the sources that were checked.

**Cursor pins.** The skill always runs, on whatever model Cursor actually uses. A pin is a preference, never a gate. A mismatch is not a failure. Evals record the model that ran and score that cell. When Cursor does not honor the pin, the skill is labeled **best effort on Cursor** in the product docs and with `best_effort_on_cursor` in the eval report.

## Consequences

The metric's denominator can grow when attribution succeeds, and it can no longer be shrunk by skipping the search. Memory for an attributed artifact carries the evidence ids and the label. The attribution eval checks the creator, the label, and that every cited id exists in the fixture. Cursor scores are filed under the observed model, or `unobserved` when the session reports none. A pin mismatch does not fail the run.

## What would change it

A dogfood result that the deep pass attributes so loosely that human files enter the 70%, or so strictly that git, logs, and manifests still leave agent-created bytes unknown. Evidence that Cursor starts honoring pins does not remove the best-effort label until a run records the requested model as the observed one. A Cursor change that stops the skill from running unless the pin matches would reopen the gate, which this record forbids.
