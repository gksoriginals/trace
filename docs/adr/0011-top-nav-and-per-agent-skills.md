# ADR-0011: Top nav chrome and per-agent skill opt-in

## Context

Pen designs for Trace M1/M2 surfaces (S1–S15) moved primary navigation from a sidebar to a top bar, folded Setup into first-run + Settings (no “re-open wizard”), and made skill opt-in **per coding-agent host** because each host has its own skills folder. Unavailable later-adapter cards (Claude/Gemini) were removed in favor of **Add agent** (re-detect).

## Decision

1. **Chrome:** Top nav — Trace mark = Home; Ask; Memory; Settings. Setup is not a primary nav item.
2. **Skills:** `SkillsOptIn` stores `agents[host] → { hygienicSetup, sessionEnd, memoryWriter }`, migrating the older flat shape on load.
3. **Install:** `skills/install.sh` accepts `--host cursor|codex|all` and `--skills a,b,c`; the app installs only opted-in skills per host.
4. **Settings:** Add agent / re-detect instead of re-opening the first-run wizard. Ask is chat-style, memory-first.

## Consequences

- Coverage receipts remain per project / per agent / per skill version (unchanged).
- Shared `~/.agents/skills` is Codex’s install root; Cursor uses `~/.cursor/skills`.
- Dogfood must re-Apply Settings after changing per-agent toggles so install.sh runs again.
