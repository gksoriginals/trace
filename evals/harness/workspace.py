"""Materialize a fixture into a temp project the driver can touch."""

from __future__ import annotations

import os
import signal
import subprocess
import time
from pathlib import Path


HARNESS_DIR = ".harness"


def materialize(fixture: dict, workspace: Path) -> None:
    workspace.mkdir(parents=True, exist_ok=True)
    deferred = _worktree_path_prefixes(fixture)
    for rel, content in (fixture.get("files") or {}).items():
        if _under_any(rel, deferred):
            continue
        path = workspace / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    apply_git(fixture, workspace)
    for rel, content in (fixture.get("files") or {}).items():
        if not _under_any(rel, deferred):
            continue
        path = workspace / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def apply_git(fixture: dict, workspace: Path) -> dict:
    """Apply optional fixture.git steps after files, before the driver.

    Returns metadata such as recorded tip shas. Steps run in a real git repo
    so session-end and attribution cases can see remotes, branches, and
    linked worktrees.
    """
    spec = fixture.get("git")
    if not spec:
        return {}
    steps = spec if isinstance(spec, list) else list(spec.get("steps") or [])
    if not steps:
        return {}
    root_rel = "." if isinstance(spec, list) else (spec.get("root") or ".")
    root = workspace if root_rel in (".", "") else workspace / root_rel
    root.mkdir(parents=True, exist_ok=True)
    meta: dict = {"shas": {}, "origin": None}
    env = _git_env()
    for step in steps:
        op = step.get("op")
        if op == "init":
            _git(root, ["init", "-b", step.get("default_branch") or "main"], env)
            _git(root, ["config", "user.name", "Trace Eval"], env)
            _git(root, ["config", "user.email", "trace-eval@example.com"], env)
        elif op == "commit":
            for rel, content in (step.get("files") or {}).items():
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            add = step.get("add")
            if add is None:
                _git(root, ["add", "-A"], env)
            else:
                for path in add:
                    _git(root, ["add", "--", path], env)
            message = step.get("message") or "commit"
            _git(root, ["commit", "--allow-empty", "-m", message], env)
            if step.get("name"):
                meta["shas"][step["name"]] = _git_out(root, ["rev-parse", "HEAD"], env)
        elif op == "branch":
            args = ["branch", step["name"]]
            if step.get("start_point"):
                args.append(step["start_point"])
            _git(root, args, env)
        elif op == "checkout":
            _git(root, ["checkout", step["ref"]], env)
        elif op == "clone_bare_as_origin":
            bare_rel = step.get("path") or f"{HARNESS_DIR}/origin.git"
            bare = workspace / bare_rel
            bare.parent.mkdir(parents=True, exist_ok=True)
            if bare.exists():
                raise RuntimeError(f"bare origin already exists: {bare_rel}")
            _git(root, ["clone", "--bare", str(root), str(bare)], env)
            _git(root, ["remote", "add", "origin", str(bare)], env)
            meta["origin"] = bare_rel
        elif op == "advance_origin":
            # Push a local ref to origin's default branch so local default can stay behind.
            local_ref = step.get("ref") or "HEAD"
            remote_branch = step.get("remote_branch") or step.get("default_branch") or "main"
            _git(root, ["push", "origin", f"{local_ref}:refs/heads/{remote_branch}"], env)
            meta["shas"]["origin/" + remote_branch] = _git_out(
                root, ["rev-parse", f"origin/{remote_branch}"], env
            )
        elif op == "fetch":
            _git(root, ["fetch", "origin"], env)
        elif op == "reset":
            _git(root, ["reset", "--hard", step["to"]], env)
        elif op == "worktree_add":
            # Fixture paths are workspace-relative (linked trees may sit beside the primary checkout).
            path = workspace / step["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            args = ["worktree", "add"]
            if step.get("detach"):
                args.append("--detach")
            args.append(str(path))
            if step.get("ref"):
                args.append(step["ref"])
            _git(root, args, env)
        elif op == "dirty":
            target = workspace / step["path"]
            for rel, content in (step.get("files") or {}).items():
                file_path = target / rel
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content, encoding="utf-8")
        elif op == "write_ignored":
            target = workspace / step["path"]
            gitignore = target / ".gitignore"
            patterns = step.get("patterns") or list((step.get("files") or {}).keys())
            existing = gitignore.read_text(encoding="utf-8") if gitignore.is_file() else ""
            lines = existing.splitlines()
            for pattern in patterns:
                name = Path(pattern).name if "/" in pattern else pattern
                if name not in lines and pattern not in lines:
                    lines.append(pattern if "/" in pattern else name)
            gitignore.write_text("\n".join(lines) + "\n", encoding="utf-8")
            for rel, content in (step.get("files") or {}).items():
                file_path = target / rel
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content, encoding="utf-8")
        else:
            raise RuntimeError(f"unknown fixture.git op: {op!r}")
    tip = _git_out(root, ["rev-parse", "HEAD"], env) if (root / ".git").exists() else None
    if tip:
        meta["shas"]["HEAD"] = tip
    (workspace / HARNESS_DIR).mkdir(parents=True, exist_ok=True)
    (workspace / HARNESS_DIR / "git-meta.json").write_text(
        __import__("json").dumps(meta, indent=2) + "\n",
        encoding="utf-8",
    )
    return meta


def start_processes(fixture: dict, workspace: Path) -> list[subprocess.Popen]:
    """Spawn optional fixture.processes (cwd-bound sleep children for in-use checks)."""
    started: list[subprocess.Popen] = []
    for spec in fixture.get("processes") or []:
        cwd = workspace / (spec.get("cwd") or ".")
        command = list(spec.get("command") or ["sleep", "120"])
        proc = subprocess.Popen(
            command,
            cwd=str(cwd),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        started.append(proc)
    if started:
        time.sleep(0.05)
    return started


def stop_processes(procs: list[subprocess.Popen]) -> None:
    for proc in procs:
        if proc.poll() is not None:
            continue
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            try:
                proc.terminate()
            except ProcessLookupError:
                pass
    for proc in procs:
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                proc.kill()


def processes_alive(procs: list[subprocess.Popen]) -> bool:
    return all(proc.poll() is None for proc in procs)


def is_harness_or_git_meta(rel: str) -> bool:
    """Paths the graders must ignore: harness bookkeeping and any git metadata."""
    parts = rel.split("/")
    if parts[0] == HARNESS_DIR:
        return True
    if ".git" in parts:
        return True
    if parts[-1] == ".git":
        return True
    return False


def _worktree_path_prefixes(fixture: dict) -> list[str]:
    spec = fixture.get("git")
    if not spec:
        return []
    steps = spec if isinstance(spec, list) else list(spec.get("steps") or [])
    prefixes = []
    for step in steps:
        if step.get("op") == "worktree_add" and step.get("path"):
            prefixes.append(step["path"].rstrip("/"))
    return prefixes


def _under_any(rel: str, prefixes: list[str]) -> bool:
    return any(rel == p or rel.startswith(p + "/") for p in prefixes)


def _git_env() -> dict:
    env = os.environ.copy()
    env.setdefault("GIT_AUTHOR_NAME", "Trace Eval")
    env.setdefault("GIT_AUTHOR_EMAIL", "trace-eval@example.com")
    env.setdefault("GIT_COMMITTER_NAME", "Trace Eval")
    env.setdefault("GIT_COMMITTER_EMAIL", "trace-eval@example.com")
    return env


def _git(cwd: Path, args: list[str], env: dict) -> None:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed in {cwd}: {result.stderr.strip() or result.stdout.strip()}"
        )


def _git_out(cwd: Path, args: list[str], env: dict) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed in {cwd}: {result.stderr.strip() or result.stdout.strip()}"
        )
    return result.stdout.strip()
