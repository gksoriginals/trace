# ADR-0004: Skills first, not a plugin

- **Status:** superseded in part by [ADR-0014](0014-v1-install-unit.md) (hooks are on by default, and the plugin bundle is the install unit). The three skills, the project rule, and no MCP still stand.
- **Date:** 2026-11-11
- **Deciders:** Gopi

## Context

The skills were still described as harness packages and hooks. Agent Skills, the format Claude Code, Cursor, and Codex load, is a portable skill directory, not a plugin and not an MCP server. Harness notes from Vercel, LangChain, and OpenAI say the same thing about how those skills actually get used: a model often skips a skill that is installed but not named. Vercel saw a skill go unused in 56% of runs. Explicit instructions raised use above 95%. Host session-end hooks, where they exist, have about 1–3 seconds. That is not enough time to do the cleanup or the write.

## Decision

Ship three portable skills in the Agent Skills format: hygienic setup, session-end cleanup, and the memory writer. They share one set of schemas, scripts, and safety rules. Install them into each host's own skills folder, for example with `npx skills add`. Whole-agent install and the per-project opt-out stay as [ADR-0002](0002-locked-product-decisions.md) locked them. A project that opted out does not get the instruction line below.

Add one line to each project's `AGENTS.md`, Cursor rule, or `CLAUDE.md` saying when to use the skills. The skill files alone are not the install.

Hooks are optional, opt-in, and per host. A hook is a stop or session-end hook. It only calls the same helper or queues work. It is not required for the skill to run. Write memory during the work or at the end of a turn, not only inside a hook.

No MCP for now. Versioned files with atomic writes are enough. A plugin comes later, and only as a thin wrapper for marketplace install or team policy.

## Consequences

One skill source serves Cursor, Codex, and, later, Claude. Safety rules are not rewritten per host. Install has two parts: the skills folder, and the one line that tells the model when to run them. A hook cannot be the only writer of memory. Trace does not ship an MCP server, and it does not register one as required for a session to start. Marketplace distribution, if M2 wants it, wraps this layout. It does not replace it.

## What would change it

A host that cannot load Agent Skills and cannot be told, in one project line, when to use them. Dogfood showing that versioned files cannot be written reliably, which would reopen a local protocol and not a plugin. A marketplace or team-policy requirement, which is the thin wrapper this record already allows.
