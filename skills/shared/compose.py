"""Compose skill + params + inputs into a prompt for a harness agent instance (mode 2)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_skill_md(skills_root: Path | str, skill_folder: str) -> str:
    path = Path(skills_root).expanduser() / skill_folder / "SKILL.md"
    return path.read_text(encoding="utf-8") if path.is_file() else f"(missing SKILL.md for {skill_folder})"


def compose_prompt(
    *,
    skill_ids: list[str],
    skill_markdown: dict[str, str],
    params: dict[str, Any],
    inputs: dict[str, Any],
    task: str,
) -> str:
    """Build the user prompt Trace sends to Cursor ACP / Codex app-server."""
    parts = [
        "You are running Trace skills inside this coding-agent session.",
        "Follow the named skill instructions. Write only the paths listed in inputs.",
        "Do not permanently delete files. Trash only exact consented paths.",
        "Do not invent Execute targets for the Trace app.",
        "",
        f"## Task\n{task.strip()}",
        "",
        "## Params\n```json\n" + json.dumps(params, indent=2, ensure_ascii=False) + "\n```",
        "",
        "## Inputs\n```json\n" + json.dumps(inputs, indent=2, ensure_ascii=False) + "\n```",
        "",
    ]
    for skill_id in skill_ids:
        md = skill_markdown.get(skill_id) or f"(no SKILL.md for {skill_id})"
        parts.append(f"## Skill: {skill_id}\n{md.strip()}\n")
    return "\n".join(parts)


# Folder names under skills/
SKILL_FOLDERS = {
    "hygienic_setup": "hygienic-setup",
    "hygienic-setup": "hygienic-setup",
    "session_end": "session-end-cleanup",
    "session-end-cleanup": "session-end-cleanup",
    "memory_writer": "memory-writer",
    "memory-writer": "memory-writer",
    "prepare_home": "prepare-home",
    "prepare-home": "prepare-home",
    "decide_later": "decide-later",
}


def compose_from_repo(
    skills_root: Path | str,
    skill_ids: list[str],
    *,
    params: dict[str, Any],
    inputs: dict[str, Any],
    task: str,
) -> str:
    root = Path(skills_root)
    markdown = {}
    for skill_id in skill_ids:
        folder = SKILL_FOLDERS.get(skill_id, skill_id)
        markdown[skill_id] = load_skill_md(root, folder)
    return compose_prompt(
        skill_ids=skill_ids,
        skill_markdown=markdown,
        params=params,
        inputs=inputs,
        task=task,
    )
