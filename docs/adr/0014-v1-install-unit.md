# ADR-0014: v1 install is skills, rule, hooks, and a plugin bundle

- **Status:** accepted
- **Date:** 2026-11-14
- **Deciders:** Gopi
- **Supersedes:** the “hooks are optional” and “a plugin comes later” clauses of [ADR-0004](0004-skills-not-a-plugin.md)

## Context

ADR-0004 shipped three portable skills, a project line, optional hooks, and no plugin. That is no longer the install. The native window app is already on main ([ADR-0006](0006-full-m0-m2-cut.md), [ADR-0012](0012-no-menu-bar-companion.md)). This record does not rebuild it and does not bring back a menu bar. It changes how skills, the rule, and hooks are installed.

## Decision

v1 installs four pieces together. Still no MCP server. The app remains the only writer of its database. Skills keep writing versioned files with atomic writes.

1. **Skills.** The same three Agent Skills, plus the shared schemas, scripts, and safety rules. Descriptions name the concrete situations (npm install, a session-ending pytest cache, a build directory that was just created) so a model can fire them without the user asking.
2. **Rule line.** One block, installed per project into `AGENTS.md`, `.cursor/rules/trace.mdc`, and `CLAUDE.md`. Writing it again replaces the block. Uninstall removes it. A per-project opt-out (`./skills/install.sh --opt-out --project …`) removes it and records `.trace/opt-out`.
3. **Hooks.** On by default for Cursor and Codex, and for Claude Code. Stop and session-end hooks only append one line to `~/.trace/hook-queue.jsonl`. That append has to finish well under a second. The hook never cleans up. The app or the next session drains the queue.
4. **Plugin.** The install unit per harness: `plugins/cursor`, `plugins/claude`, and `plugins/codex`. Each bundle carries the hook script and a manifest. `./skills/install.sh` is the installer that writes skills, the rule, and the hooks in one step, and the matching uninstall.

## Consequences

`install.sh` still copies skills into `~/.cursor/skills` and `~/.agents/skills`, which is what the app calls. `--host claude` is available and is not the default. A second install does not duplicate the rule or the hook commands. Opt-out is per project and does not delete the host skill folders. Memory is still written during the turn. The hook is only a queue.

## What would change it

A host whose session-end budget cannot fit a single append. Dogfood showing the default hooks enqueue so often that sessions stall. A decision to add MCP, which this record still refuses.
