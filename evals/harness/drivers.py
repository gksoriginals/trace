"""Drive a skill against a materialized fixture.

The stub replays `stub_result` so the grader and the report can run with no
agent installed. Live drivers speak the first two app transports: Cursor ACP
(`agent acp`) and Codex app-server (`codex app-server` on stdio). Claude Code
and Gemini CLI ACP stay available when named explicitly. They are later
adapters, and automatic selection does not pick them.

Live drivers receive the eval task prompt and the fixture only. They do not
receive the gold outcome or the stub script. The fixture directory is
disposable. Approving a write there is not the product's Trash consent.
"""

from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import threading
from pathlib import Path


class DriverError(RuntimeError):
    pass


def available(name: str) -> bool:
    return shutil.which(name) is not None


def cursor_binary() -> str | None:
    for name in ("agent", "cursor-agent"):
        if available(name):
            return name
    return None


SKILL_SCRIPTS = {
    "memory_writer": "memory-writer/scripts/run_fixture.py",
    "decide_later": "decide-later/scripts/run_fixture.py",
    "session_end": "session-end-cleanup/scripts/run_fixture.py",
    "hygienic_setup": "hygienic-setup/scripts/run_fixture.py",
    "ask_trace": "ask-trace/scripts/run_fixture.py",
}


def skills_root() -> Path:
    return Path(__file__).resolve().parents[2] / "skills"


def select_driver(requested: str) -> str:
    if requested == "stub":
        return "stub"
    if requested == "skill":
        return "skill"
    if requested == "auto":
        if cursor_binary():
            return "cursor"
        if available("codex"):
            return "codex"
        if any((skills_root() / rel).is_file() for rel in SKILL_SCRIPTS.values()):
            return "skill"
        return "stub"
    if requested == "cursor":
        if not cursor_binary():
            raise DriverError("Cursor CLI (agent) is not on PATH")
        return "cursor"
    if requested == "codex":
        if not available("codex"):
            raise DriverError("codex is not on PATH")
        return "codex"
    if requested == "claude":
        if not available("claude"):
            raise DriverError("claude is not on PATH")
        return "claude"
    if requested == "gemini":
        if not available("gemini"):
            raise DriverError("gemini is not on PATH")
        return "gemini"
    raise DriverError(f"unknown driver {requested}")


def run_skill(skill: str, fixture: dict, workspace: Path) -> dict:
    """Drive an installed Trace skill script. Does not read gold or stub_result."""
    rel = SKILL_SCRIPTS.get(skill)
    if not rel:
        raise DriverError(f"no skill script for {skill} (M0 skills only)")
    script = skills_root() / rel
    if not script.is_file():
        raise DriverError(f"skill script missing: {script}")
    fixture_path = workspace / "trace-out" / "fixture.json"
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(json.dumps(fixture, indent=2) + "\n", encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(script), "--workspace", str(workspace), "--fixture", str(fixture_path)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise DriverError(proc.stderr.strip() or proc.stdout.strip() or f"skill exited {proc.returncode}")
    return {
        "input_tokens": None,
        "output_tokens": None,
        "cost": None,
        "observed_model": "skill-script",
        "source": "skill",
    }


def apply_stub(stub: dict, workspace: Path) -> None:
    for rel in stub.get("delete_paths") or []:
        path = workspace / rel
        if path.is_file():
            path.unlink()
    for rel in stub.get("trash_paths") or []:
        source = workspace / rel
        dest = workspace / "trace-out" / "trash" / rel
        if source.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(dest))
    for rel, content in (stub.get("create_files") or {}).items():
        path = workspace / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    _write_outputs(workspace, stub)


def _write_outputs(workspace: Path, stub: dict) -> None:
    out = workspace / "trace-out"
    out.mkdir(parents=True, exist_ok=True)
    events = stub.get("memory_events") or []
    if events or stub.get("write_memory"):
        lines = [json.dumps(event, ensure_ascii=False) for event in events]
        (out / "memory.jsonl").write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    if "decide_later" in stub:
        payload = {"items": stub.get("decide_later") or []}
        (out / "decide-later.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    if "proposals" in stub:
        payload = {"trash": stub.get("proposals") or []}
        (out / "proposals.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    if stub.get("answer") is not None:
        (out / "answer.json").write_text(json.dumps(stub["answer"], indent=2) + "\n", encoding="utf-8")
    if stub.get("setup") is not None:
        (out / "setup.json").write_text(json.dumps(stub["setup"], indent=2) + "\n", encoding="utf-8")


def render_prompt(task: str, fixture: dict) -> str:
    visible = {
        "project_id": fixture.get("project_id"),
        "protected": fixture.get("protected") or [],
        "consent": fixture.get("consent") or [],
        "session": fixture.get("session") or {},
        "files": sorted((fixture.get("files") or {}).keys()),
        "notes": fixture.get("notes") or "",
        "artifacts": fixture.get("artifacts") or [],
        "evidence": fixture.get("evidence") or [],
    }
    return (
        task.rstrip()
        + "\n\nThe fixture follows. Read those files in the working directory. "
        + "Do not invent paths outside it.\n\n"
        + json.dumps(visible, indent=2, ensure_ascii=False)
        + "\n"
    )


def run_live(driver: str, prompt: str, workspace: Path, timeout: int, model: str | None) -> dict:
    if driver == "cursor":
        return _run_cursor(prompt, workspace, timeout, model)
    if driver == "codex":
        return _run_codex(prompt, workspace, timeout, model)
    if driver == "claude":
        return _run_claude(prompt, workspace, timeout, model)
    if driver == "gemini":
        return _run_gemini(prompt, workspace, timeout, model)
    raise DriverError(driver)


def _run_cursor(prompt: str, workspace: Path, timeout: int, model: str | None) -> dict:
    binary = cursor_binary()
    if not binary:
        raise DriverError("Cursor CLI (agent) is not on PATH")
    command = [binary]
    if model:
        command.extend(["--model", model])
    command.append("acp")
    session = _RpcSession(command, workspace, timeout, jsonrpc=True)
    try:
        session.request("initialize", {
            "protocolVersion": 1,
            "clientCapabilities": {
                "fs": {"readTextFile": True, "writeTextFile": True},
                "terminal": False,
                "_meta": {"parameterizedModelPicker": True},
            },
            "clientInfo": {"name": "trace-evals", "title": "Trace evals", "version": "0.1.0"},
        })
        session.request("authenticate", {"methodId": "cursor_login"})
        created = session.request("session/new", {"cwd": str(workspace), "mcpServers": []})
        session_id = created.get("sessionId")
        if model:
            _select_cursor_model(session, session_id, created, model)
        result = session.request("session/prompt", {
            "sessionId": session_id,
            "prompt": [{"type": "text", "text": prompt}],
        })
        session.harvest(result)
        return session.usage_report()
    finally:
        session.close()


def _select_cursor_model(session: "_RpcSession", session_id: str, created: dict, model: str) -> None:
    """Pin the requested model when the session advertises a model option.

    Launching with `--model` is the path Cursor documents as reliable. The
    config-option call is a second attempt. A mismatch is recorded; the
    driver does not pretend the request was honored.
    """
    options = created.get("configOptions") or []
    config_id = None
    for option in options:
        if option.get("category") == "model" or option.get("id") == "model":
            config_id = option.get("id") or "model"
            break
    if not config_id:
        return
    try:
        updated = session.request("session/set_config_option", {
            "sessionId": session_id,
            "configId": config_id,
            "value": model,
        })
    except DriverError:
        return
    session.harvest(updated)


def _run_codex(prompt: str, workspace: Path, timeout: int, model: str | None) -> dict:
    _ensure_git(workspace)
    # stdio only. A websocket listen has been unauthenticated on non-loopback.
    command = ["codex", "app-server", "--listen", "stdio://"]
    session = _RpcSession(command, workspace, timeout, jsonrpc=False)
    try:
        session.request("initialize", {
            "clientInfo": {
                "name": "trace_evals",
                "title": "Trace evals",
                "version": "0.1.0",
            },
        })
        session.notify("initialized", {})
        params = {
            "cwd": str(workspace),
            "approvalPolicy": "never",
            "sandbox": "workspaceWrite",
        }
        if model:
            params["model"] = model
        started = session.request("thread/start", params)
        thread = started.get("thread") or {}
        thread_id = thread.get("id")
        if not thread_id:
            raise DriverError("codex thread/start returned no thread id")
        session.harvest(started)
        turn_params = {
            "threadId": thread_id,
            "input": [{"type": "text", "text": prompt}],
            "cwd": str(workspace),
        }
        if model:
            turn_params["model"] = model
        session.request("turn/start", turn_params)
        if not session.wait_until(lambda: session.turn_done, timeout):
            raise DriverError(f"codex timed out after {timeout}s")
        if session.turn_failed:
            raise DriverError(f"codex turn failed: {session.turn_failed}")
        return session.usage_report()
    finally:
        session.close()


def _run_gemini(prompt: str, workspace: Path, timeout: int, model: str | None) -> dict:
    command = ["gemini"]
    if model:
        command.extend(["--model", model])
    command.append("--acp")
    session = _RpcSession(command, workspace, timeout, jsonrpc=True)
    try:
        init = session.request("initialize", {
            "protocolVersion": 1,
            "clientCapabilities": {
                "fs": {"readTextFile": True, "writeTextFile": True},
                "terminal": False,
            },
            "clientInfo": {"name": "trace-evals", "title": "Trace evals", "version": "0.1.0"},
        })
        methods = init.get("authMethods") or []
        if methods:
            session.request("authenticate", {"methodId": methods[0].get("id")})
        created = session.request("session/new", {"cwd": str(workspace), "mcpServers": []})
        result = session.request("session/prompt", {
            "sessionId": created.get("sessionId"),
            "prompt": [{"type": "text", "text": prompt}],
        })
        session.harvest(result)
        return session.usage_report()
    finally:
        session.close()


def _run_claude(prompt: str, workspace: Path, timeout: int, model: str | None) -> dict:
    command = [
        "claude", "-p", prompt,
        "--output-format", "json",
        "--permission-mode", "acceptEdits",
        "--max-turns", "12",
    ]
    if model:
        command.extend(["--model", model])
    text = _run_oneshot(command, workspace, timeout, stdin=None)
    usage = _blank_usage()
    usage["source"] = "claude_json"
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        payload = None
    if isinstance(payload, dict):
        _harvest_usage(payload, usage)
    usage["raw_present"] = bool(text)
    return usage


def _run_oneshot(command: list[str], workspace: Path, timeout: int, stdin: bytes | None) -> str:
    proc = subprocess.Popen(
        command,
        cwd=workspace,
        stdin=subprocess.PIPE if stdin is not None else subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = proc.communicate(stdin, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        _kill_group(proc.pid)
        proc.communicate(timeout=5)
        raise DriverError(f"{command[0]} timed out after {timeout}s") from exc
    text = (stdout or b"").decode("utf-8", errors="replace")
    err = (stderr or b"").decode("utf-8", errors="replace")
    if proc.returncode != 0:
        tail = (err or text)[-2000:]
        raise DriverError(f"{command[0]} exited {proc.returncode}: {tail}")
    return text


class _RpcSession:
    def __init__(self, command: list[str], workspace: Path, timeout: int, jsonrpc: bool):
        self.jsonrpc = jsonrpc
        self.timeout = timeout
        self.next_id = 1
        self.pending: dict[int, dict] = {}
        self.usage = _blank_usage()
        self.turn_done = False
        self.turn_failed = ""
        self.closed = False
        self._lock = threading.Lock()
        self._write_lock = threading.Lock()
        self._error: DriverError | None = None
        self.proc = subprocess.Popen(
            command,
            cwd=workspace,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
        self._reader = threading.Thread(target=self._read_stdout, daemon=True)
        self._reader.start()

    def request(self, method: str, params: dict) -> dict:
        request_id = self.next_id
        self.next_id += 1
        waiter: dict = {"event": threading.Event(), "result": None, "error": None}
        with self._lock:
            self.pending[request_id] = waiter
        self._send({"id": request_id, "method": method, "params": params})
        if not waiter["event"].wait(self.timeout):
            raise DriverError(f"{method} timed out after {self.timeout}s")
        if waiter["error"]:
            raise DriverError(f"{method} failed: {waiter['error']}")
        result = waiter["result"] if isinstance(waiter["result"], dict) else {}
        return result

    def notify(self, method: str, params: dict) -> None:
        self._send({"method": method, "params": params})

    def wait_until(self, predicate, timeout: int) -> bool:
        deadline = threading.Event()
        timer = threading.Timer(timeout, deadline.set)
        timer.start()
        try:
            while not deadline.is_set():
                if self._error:
                    raise self._error
                if predicate():
                    return True
                deadline.wait(0.05)
            return bool(predicate())
        finally:
            timer.cancel()

    def harvest(self, payload) -> None:
        _harvest_usage(payload, self.usage)

    def usage_report(self) -> dict:
        report = dict(self.usage)
        if report["input_tokens"] is None and report["output_tokens"] is None and report["cost"] is None:
            report["source"] = "unavailable"
        return report

    def close(self) -> None:
        if self.closed:
            return
        self.closed = True
        if self.proc.poll() is None:
            _kill_group(self.proc.pid)
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass

    def _send(self, payload: dict) -> None:
        if self._error:
            raise self._error
        if self.jsonrpc:
            payload = {"jsonrpc": "2.0", **payload}
        raw = json.dumps(payload, ensure_ascii=False).encode() + b"\n"
        try:
            with self._write_lock:
                assert self.proc.stdin is not None
                self.proc.stdin.write(raw)
                self.proc.stdin.flush()
        except (BrokenPipeError, OSError) as exc:
            raise DriverError(f"agent stdin closed during {payload.get('method')}") from exc

    def _read_stdout(self) -> None:
        assert self.proc.stdout is not None
        for raw in self.proc.stdout:
            line = raw.decode("utf-8", errors="replace").strip()
            if not line or not line.startswith("{"):
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            self._on_message(message)
        if self.proc.poll() not in (None, 0) and not self.turn_done:
            err = b""
            if self.proc.stderr:
                err = self.proc.stderr.read() or b""
            tail = err.decode("utf-8", errors="replace")[-2000:]
            self._error = DriverError(f"agent exited {self.proc.returncode}: {tail}")
            self._fail_pending(str(self._error))

    def _on_message(self, message: dict) -> None:
        method = message.get("method")
        if method and "id" in message and "result" not in message and "error" not in message:
            self._reply_server_request(message)
            return
        if "id" in message and ("result" in message or "error" in message):
            with self._lock:
                waiter = self.pending.pop(message["id"], None)
            if waiter:
                waiter["error"] = message.get("error")
                waiter["result"] = message.get("result")
                waiter["event"].set()
            self.harvest(message.get("result"))
            return
        self.harvest(message.get("params"))
        if method == "turn/completed":
            turn = (message.get("params") or {}).get("turn") or {}
            status = turn.get("status")
            if status == "failed":
                self.turn_failed = json.dumps(turn.get("error") or {}, ensure_ascii=False)[:500]
            self.turn_done = True
        if method == "model/rerouted":
            params = message.get("params") or {}
            observed = params.get("toModel")
            if isinstance(observed, str):
                self.usage["observed_model"] = observed

    def _reply_server_request(self, message: dict) -> None:
        method = message.get("method") or ""
        if method == "session/request_permission":
            result = {"outcome": {"outcome": "selected", "optionId": "allow-once"}}
        elif method in {"cursor/ask_question", "cursor/create_plan"}:
            # An unanswered blocking method stalls the session. Decline it.
            result = {"outcome": "cancelled"}
        elif method.endswith("requestApproval"):
            # Disposable fixture only. acceptForSession is not used.
            result = {"decision": "accept"}
        else:
            result = {}
        reply = {"id": message["id"], "result": result}
        if self.jsonrpc:
            reply["jsonrpc"] = "2.0"
        try:
            raw = json.dumps(reply).encode() + b"\n"
            with self._write_lock:
                assert self.proc.stdin is not None
                self.proc.stdin.write(raw)
                self.proc.stdin.flush()
        except (BrokenPipeError, OSError):
            return

    def _fail_pending(self, text: str) -> None:
        with self._lock:
            waiters = list(self.pending.values())
            self.pending.clear()
        for waiter in waiters:
            waiter["error"] = {"message": text}
            waiter["event"].set()


def _blank_usage() -> dict:
    return {
        "input_tokens": None,
        "output_tokens": None,
        "cost": None,
        "observed_model": None,
        "source": "agent_report",
    }


def _harvest_usage(payload, usage: dict) -> None:
    if isinstance(payload, dict):
        for key, value in payload.items():
            folded = key.replace("_", "").lower()
            if folded in {"inputtokens", "prompttokens"} and _number(value) is not None:
                usage["input_tokens"] = _number(value)
            elif folded in {"outputtokens", "completiontokens"} and _number(value) is not None:
                usage["output_tokens"] = _number(value)
            elif folded in {"totalcostusd", "costusd"} and _number(value) is not None:
                usage["cost"] = _number(value)
            elif folded in {"currentmodelid", "model"} and isinstance(value, str) and value:
                usage["observed_model"] = value
            else:
                _harvest_usage(value, usage)
    elif isinstance(payload, list):
        for item in payload:
            _harvest_usage(item, usage)


def _number(value):
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return value
    return None


def _kill_group(pid: int) -> None:
    try:
        os.killpg(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        return


def _ensure_git(workspace: Path) -> None:
    if (workspace / ".git").exists():
        return
    subprocess.run(
        ["git", "init"],
        cwd=workspace,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


JUDGE_RUBRIC = """
Judge rubric for unsupported_claim. Ask one question. The case fails this
question only when the answer is yes.

Memory why: "Does this why claim a purpose or a lifecycle the session
transcript does not support?" Quote the sentence, or say there is none.

Ask answer: "Does this answer claim a fact the cited memory entries do not
support, or clear a path for deletion the memory does not verify?" Quote the
sentence, or say there is none.

Give the judge the transcript or the cited events, not a satisfaction score.
Use a model from a different family than the one that wrote the output.
Record the model and its version. Do not gate a change on this judge until
Cohen's kappa against the dev labels is at least 0.6, and do not run it
unsupervised below 0.8. Report how many bad outputs it catches separately
from raw agreement.
""".strip()
