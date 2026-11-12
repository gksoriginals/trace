# ADR-0007: Markdown memory and two skill invocation modes

- **Status:** accepted
- **Date:** 2026-11-12
- **Deciders:** Gopi

## Context

The firm memory **fields** (engineering v1) were stored as JSONL; the index path was a directional `index.json` guess. Coding agents work better with readable markdown. Home insight cards should be prepared by skills, not fat app parsers. App-triggered work should compose the same skills into a host harness prompt rather than a Trace-owned multi-agent orchestrator ([ADR-0004](0004-skills-not-a-plugin.md), PRD skills/app split). Meta’s thin-orchestrator article informs *thin Trace logic*, not a Meta-style router inside Trace.

## Decision

1. **Medium:** Store project memory as markdown notes with YAML frontmatter carrying the firm v1 fields. Index is `~/.trace/index.md`. Decide-later is `decide-later.md`. Insights are `insights.md`. Field *meanings* are unchanged; JSONL as the product store is superseded.
2. **Two invocation modes (already in the PRD, made explicit):**
   - **In-session:** installed skills run inside Cursor/Codex while the user works.
   - **Composed prompt:** the app opens a Cursor ACP / Codex app-server instance and sends skill id(s) + `SKILL.md` + params + inputs. Domain work stays in the skill.
3. **prepare-home** is an operational skill that writes insight cards and applies retention/`status` on memory notes. Decide-later rows are not deleted for age.
4. Home open remains file-only. Refresh/Run/agent Ask use mode 2.

## Consequences

Evals parse frontmatter or export the same in-memory events to grader shapes without a second divergent writer. Engineering path guesses update to `.md`. App code stays a thin renderer + session bridge + Trash gates.

## What would change it

Evidence that frontmatter cannot carry firm fields reliably for graders. A host that cannot load Agent Skills and cannot accept a composed skill prompt.
