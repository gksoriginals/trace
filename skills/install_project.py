#!/usr/bin/env python3
"""Project rule line and stop/session-end hooks.

Idempotent and removable. Hooks only point at skills/hooks/enqueue.py.
A project with .trace/opt-out does not get the rule or the hooks.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

START = "<!-- trace-rule:start -->"
END = "<!-- trace-rule:end -->"
RULE = (
    "Use the Trace skills without being asked: trace-hygienic-setup before an install "
    "or environment setup (npm install, pnpm install, pip install, a python venv, a "
    "container image, model weights, or a dataset copy), trace-session-end when a "
    "session is ending and it left a pytest cache, dist directory, or scratch file, "
    "and trace-memory-writer when the session created a build directory, created a "
    "cache, or created a virtualenv. Doubtful storage goes to Decide-later. "
    "Do not guess, and do not delete anything from a hook."
)
BLOCK = f"{START}\n## Trace\n\n{RULE}\n{END}\n"
ENQUEUE = ".trace/hooks/enqueue.py"
HOOK_MARK = ".trace/hooks/enqueue.py"


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


def _upsert(text: str) -> str:
    if START in text and END in text:
        pre, rest = text.split(START, 1)
        _, post = rest.split(END, 1)
        return pre + BLOCK + post.lstrip("\n")
    if "trace-memory-writer" in text or "trace-hygienic-setup" in text:
        return text.rstrip() + "\n\n" + BLOCK
    body = text.rstrip()
    if not body:
        return BLOCK
    return body + "\n\n" + BLOCK


def _strip(text: str) -> str:
    if START not in text or END not in text:
        return text
    pre, rest = text.split(START, 1)
    _, post = rest.split(END, 1)
    merged = (pre.rstrip() + "\n" + post.lstrip("\n")).strip()
    return (merged + "\n") if merged else ""


def _cursor_rule(path: Path) -> None:
    front = (
        "---\n"
        "description: When to use Trace skills, even if the user did not name Trace.\n"
        "alwaysApply: true\n"
        "---\n\n"
    )
    _atomic_write(path, front + BLOCK)


def install_rules(project: Path) -> list[str]:
    project.mkdir(parents=True, exist_ok=True)
    written = []
    agents = project / "AGENTS.md"
    current = agents.read_text(encoding="utf-8") if agents.is_file() else ""
    _atomic_write(agents, _upsert(current))
    written.append(str(agents))
    claude = project / "CLAUDE.md"
    current = claude.read_text(encoding="utf-8") if claude.is_file() else ""
    _atomic_write(claude, _upsert(current))
    written.append(str(claude))
    rule = project / ".cursor" / "rules" / "trace.mdc"
    _cursor_rule(rule)
    written.append(str(rule))
    return written


def remove_rules(project: Path) -> None:
    for rel in ("AGENTS.md", "CLAUDE.md"):
        path = project / rel
        if not path.is_file():
            continue
        stripped = _strip(path.read_text(encoding="utf-8"))
        if stripped.strip():
            _atomic_write(path, stripped if stripped.endswith("\n") else stripped + "\n")
        else:
            path.unlink()
    rule = project / ".cursor" / "rules" / "trace.mdc"
    if rule.is_file() and START in rule.read_text(encoding="utf-8"):
        rule.unlink()


def _load_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def _is_ours(command: str) -> bool:
    return HOOK_MARK in command


def _cursor_hooks(data: dict, command: str) -> dict:
    data = dict(data)
    data["version"] = data.get("version") or 1
    hooks = dict(data.get("hooks") or {})
    for event in ("stop", "sessionEnd"):
        kept = [item for item in (hooks.get(event) or []) if not _is_ours(str(item.get("command", "")))]
        kept.append({"command": command})
        hooks[event] = kept
    data["hooks"] = hooks
    return data


def _claude_or_codex_hooks(data: dict, command: str) -> dict:
    data = dict(data)
    hooks = dict(data.get("hooks") or {})
    for event in ("Stop", "SessionEnd"):
        groups = []
        for group in hooks.get(event) or []:
            inner = [item for item in (group.get("hooks") or []) if not _is_ours(str(item.get("command", "")))]
            if inner:
                group = dict(group)
                group["hooks"] = inner
                groups.append(group)
        groups.append({"hooks": [{"type": "command", "command": command, "timeout": 3}]})
        hooks[event] = groups
    data["hooks"] = hooks
    return data


def _strip_commands(data: dict) -> dict:
    data = dict(data)
    hooks = dict(data.get("hooks") or {})
    for event, groups in list(hooks.items()):
        if not isinstance(groups, list):
            continue
        if groups and isinstance(groups[0], dict) and "command" in groups[0] and "hooks" not in groups[0]:
            hooks[event] = [item for item in groups if not _is_ours(str(item.get("command", "")))]
        else:
            kept = []
            for group in groups:
                if not isinstance(group, dict):
                    kept.append(group)
                    continue
                inner = [item for item in (group.get("hooks") or []) if not _is_ours(str(item.get("command", "")))]
                if inner:
                    group = dict(group)
                    group["hooks"] = inner
                    kept.append(group)
            hooks[event] = kept
    data["hooks"] = hooks
    return data


def install_hooks(project: Path, script_src: Path) -> None:
    dest = project / ENQUEUE
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(script_src.read_text(encoding="utf-8"), encoding="utf-8")
    dest.chmod(0o755)
    command = f"python3 {ENQUEUE}"
    cursor = project / ".cursor" / "hooks.json"
    _atomic_write(cursor, json.dumps(_cursor_hooks(_load_json(cursor), command), indent=2) + "\n")
    codex = project / ".codex" / "hooks.json"
    _atomic_write(codex, json.dumps(_claude_or_codex_hooks(_load_json(codex), command), indent=2) + "\n")
    claude = project / ".claude" / "settings.json"
    _atomic_write(claude, json.dumps(_claude_or_codex_hooks(_load_json(claude), command), indent=2) + "\n")


def remove_hooks(project: Path) -> None:
    for rel in (".cursor/hooks.json", ".codex/hooks.json", ".claude/settings.json"):
        path = project / rel
        if not path.is_file():
            continue
        cleaned = _strip_commands(_load_json(path))
        hooks = cleaned.get("hooks") or {}
        empty = all(not value for value in hooks.values())
        if empty and rel.endswith("hooks.json"):
            path.unlink()
        else:
            _atomic_write(path, json.dumps(cleaned, indent=2) + "\n")
    script = project / ENQUEUE
    if script.is_file():
        script.unlink()


def opted_out(project: Path) -> bool:
    return (project / ".trace" / "opt-out").is_file()


def wire(project: Path, script_src: Path) -> str:
    if opted_out(project):
        return f"opt-out present at {project}/.trace/opt-out; left rules and hooks off"
    install_rules(project)
    install_hooks(project, script_src)
    return f"wired rules and hooks in {project}"


def unwire(project: Path) -> str:
    remove_rules(project)
    remove_hooks(project)
    return f"removed Trace rules and hooks from {project}"


def opt_out(project: Path) -> str:
    unwire(project)
    marker = project / ".trace" / "opt-out"
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text("opt-out\n", encoding="utf-8")
    return f"opted out {project}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Install or remove the Trace project rule and hooks")
    parser.add_argument("--project", required=True)
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument("--opt-out", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    project = Path(args.project).expanduser()
    script = Path(__file__).resolve().parent / "hooks" / "enqueue.py"
    if args.dry_run:
        action = "opt-out" if args.opt_out else "uninstall" if args.uninstall else "wire"
        print(f"would {action} {project}")
        return 0
    if args.opt_out:
        print(opt_out(project))
    elif args.uninstall:
        print(unwire(project))
    else:
        print(wire(project, script))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
