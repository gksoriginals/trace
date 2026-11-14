# Trace install unit

One install wires three things: the skills, the project rule, and the hooks. There is no MCP server.

The command the app already calls is still the one to use:

```bash
./skills/install.sh --project ~/code/my-project
./skills/install.sh --host cursor --project ~/code/my-project
./skills/install.sh --uninstall --project ~/code/my-project
./skills/install.sh --opt-out --project ~/code/my-project
```

`--host all` copies skills into the Cursor and Codex folders, which is what the app does. `--host claude` copies them into `~/.claude/skills`. A project install also writes the rule into `AGENTS.md`, `.cursor/rules/trace.mdc`, and `CLAUDE.md`, and writes stop / session-end hooks for Cursor, Codex, and Claude Code. Those hooks only append to `~/.trace/hook-queue.jsonl`.

The directories next to this file are the per-harness bundles (Cursor plugin, Claude Code plugin, Codex plugin). Each one carries the hook script and a manifest. Enable the bundle in that host if it loads local plugins. If it does not, the installer above is the whole install.
