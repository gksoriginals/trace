#!/usr/bin/env python3
"""Run Trace skill evals and print a report.

Default driver is automatic: Cursor if `agent` is on PATH, otherwise Codex
if `codex` is on PATH, otherwise the stub. Claude and Gemini are later
adapters and run only when named with --agent. The stub replays a scripted
outcome so this command finishes with no agent installed. Calibration cases
always use the stub. They are planted failures, and a live agent that behaved
well would hide a grader bug.

Each invocation is one agent×model cell. Pass --agent and --model. The
report gives that cell's pass rate, its variance, and its usage, then a
best-value pick across the cells in the report. One cell cannot crown a
cheaper model. See docs/evals.md.

This is not a CI gate.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from harness.drivers import (
    JUDGE_RUBRIC,
    SKILL_SCRIPTS,
    DriverError,
    apply_stub,
    render_prompt,
    run_live,
    run_skill,
    select_driver,
)
from harness.graders import failed_names, grade
from harness.stats import (
    article_kappa_example,
    best_value,
    bootstrap_ci,
    detection_floor,
    paired_diff_ci,
    pass_power,
    wilson,
)
from harness.workspace import (
    materialize,
    processes_alive,
    start_processes,
    stop_processes,
)


SKILLS = (
    "hygienic_setup",
    "session_end",
    "memory_writer",
    "decide_later",
    "ask_trace",
    "attribution",
)
AGENTS = ("auto", "stub", "skill", "cursor", "codex", "claude", "gemini")
FIRST_AGENTS = ("cursor", "codex")
M0_SKILLS = tuple(SKILL_SCRIPTS)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run Trace skill outcome evals")
    parser.add_argument("--agent", default="auto", choices=AGENTS)
    parser.add_argument("--model", default=None, help="Model id for this agent. Omit to use the agent's own default.")
    parser.add_argument("--skill", choices=SKILLS)
    parser.add_argument("--split", default="test", choices=("test", "dev", "all"))
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--judge", action="store_true")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args(argv)

    kappa = article_kappa_example()
    if abs(kappa - 0.15) > 0.02:
        print(f"kappa self-check failed: article example scored {kappa:.3f}, expected about 0.15")
        return 2
    if not _best_value_self_check():
        print("best-value self-check failed: the cheaper equal-quality model should win, and a safety miss should not")
        return 2
    if not _cursor_pin_self_check():
        print("cursor pin self-check failed: a mismatch is not a failure, and the score follows the observed model")
        return 2
    if args.repeats < 1:
        print("--repeats must be at least 1")
        return 2

    try:
        driver = select_driver(args.agent)
    except DriverError as exc:
        print(exc)
        return 2

    cases = load_cases(args.skill)
    if args.list:
        for case in cases:
            print(f"{case['split']:12} {case['skill']:18} {case['id']}")
        return 0

    headline = [c for c in cases if c["split"] != "calibration" and _in_split(c, args.split)]
    if driver == "skill":
        headline = [c for c in headline if c["skill"] in M0_SKILLS]
    calibration = [c for c in cases if c["split"] == "calibration"]
    if driver == "skill" and args.skill:
        calibration = [c for c in calibration if c.get("skill") == args.skill]
    elif driver == "skill":
        calibration = [c for c in calibration if c.get("skill") in M0_SKILLS]
    tasks = {skill: (ROOT / "tasks" / f"{skill}.md").read_text(encoding="utf-8") for skill in SKILLS}

    runs: list[list[dict]] = []
    for _ in range(args.repeats):
        runs.append([
            run_case(case, driver, tasks[case["skill"]], args.timeout, args.model, planted=False)
            for case in headline
        ])
    cal_results = [
        run_case(case, "stub", tasks.get(case["skill"], ""), args.timeout, None, planted=True)
        for case in calibration
    ]

    report = build_report(driver, args, headline, runs, cal_results, kappa)
    if args.baseline:
        report["baseline"] = compare_baseline(args.baseline, report)

    out = ROOT / "out"
    out.mkdir(parents=True, exist_ok=True)
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print_report(report)
    return 0 if report["ok"] else 1


def _best_value_self_check() -> bool:
    picks = best_value([
        {"agent": "cursor", "model": "pricey", "pass_rate": 1.0, "safety_fails": 0, "cost": 9},
        {"agent": "cursor", "model": "cheap", "pass_rate": 1.0, "safety_fails": 0, "cost": 2},
        {"agent": "cursor", "model": "unsafe", "pass_rate": 1.0, "safety_fails": 1, "cost": 0.1},
        {"agent": "codex", "model": "solo", "pass_rate": 0.5, "safety_fails": 0, "cost": None},
    ])
    return picks["cursor"]["model"] == "cheap" and picks["codex"]["basis"] == "only_model"


def _cursor_pin_self_check() -> bool:
    scored_on_observed = _model_label("cursor", "pinned-fast", "composer-other") == "composer-other"
    unobserved = _model_label("cursor", "pinned-fast", None) == "unobserved"
    mismatch_is_best_effort = _best_effort_on_cursor("cursor", "pinned-fast", "composer-other")
    match_is_not = not _best_effort_on_cursor("cursor", "pinned-fast", "pinned-fast")
    other_agent = not _best_effort_on_cursor("codex", "a", "b")
    no_pin = not _best_effort_on_cursor("cursor", None, "whatever")
    return all((scored_on_observed, unobserved, mismatch_is_best_effort, match_is_not, other_agent, no_pin))


def _best_effort_on_cursor(driver: str, requested: str | None, observed: str | None) -> bool:
    """A Cursor pin is a preference. Ignoring it does not fail the skill."""
    if driver != "cursor" or not requested:
        return False
    return observed != requested


def load_cases(skill: str | None) -> list[dict]:
    cases = []
    for path in sorted((ROOT / "cases").rglob("*.json")):
        case = json.loads(path.read_text(encoding="utf-8"))
        case["_path"] = str(path.relative_to(ROOT))
        if case.get("split") == "calibration":
            cases.append(case)
            continue
        if skill and case.get("skill") != skill:
            continue
        cases.append(case)
    return cases


def _in_split(case: dict, split: str) -> bool:
    if split == "all":
        return case["split"] in {"test", "dev"}
    return case["split"] == split


def run_case(case: dict, driver: str, task: str, timeout: int, model: str | None, planted: bool) -> dict:
    fixture = case["fixture"]
    expected = case["expected"]
    with tempfile.TemporaryDirectory(prefix="trace-eval-") as tmp:
        workspace = Path(tmp)
        materialize(fixture, workspace)
        procs = start_processes(fixture, workspace)
        driver_note = ""
        usage = None
        try:
            try:
                if planted or driver == "stub":
                    apply_stub(case.get("stub_result") or {}, workspace)
                    driver_note = "stub"
                elif driver == "skill":
                    usage = run_skill(case["skill"], fixture, workspace)
                    driver_note = "skill"
                else:
                    prompt = render_prompt(task, fixture)
                    usage = run_live(driver, prompt, workspace, timeout, model)
                    driver_note = driver
                alive = processes_alive(procs) if procs else None
                checks = grade(fixture, expected, workspace, processes_alive=alive)
            except (DriverError, OSError, json.JSONDecodeError) as exc:
                return _row(case, False, ["driver_error"], [f"driver_error: {exc}"], driver_note or driver, None)
        finally:
            stop_processes(procs)
    failed = failed_names(checks)
    return _row(
        case,
        not failed,
        failed,
        [f"{c.name}: {c.detail}" for c in checks if not c.passed],
        driver_note,
        usage,
    )


def _row(case, passed, failed, details, driver, usage) -> dict:
    expected_fail = case.get("expect_fail_checks") or []
    caught = (not passed) and all(name in failed for name in expected_fail)
    return {
        "id": case["id"],
        "skill": case["skill"],
        "split": case["split"],
        "title": case.get("title", ""),
        "passed": passed,
        "failed_checks": failed,
        "details": details,
        "driver": driver,
        "expect_fail_checks": expected_fail,
        "calibration_caught": caught if case["split"] == "calibration" else None,
        "usage": _usage_note(usage, driver),
    }


def _usage_note(usage: dict | None, driver: str) -> dict:
    if driver == "stub" or not usage:
        return {
            "input_tokens": None,
            "output_tokens": None,
            "cost": None,
            "observed_model": None,
            "source": "scripted" if driver == "stub" else "unavailable",
        }
    if driver == "skill":
        return {
            "input_tokens": None,
            "output_tokens": None,
            "cost": None,
            "observed_model": (usage or {}).get("observed_model") or "skill-script",
            "source": "skill",
        }
    return {
        "input_tokens": usage.get("input_tokens"),
        "output_tokens": usage.get("output_tokens"),
        "cost": usage.get("cost"),
        "observed_model": usage.get("observed_model"),
        "source": usage.get("source") or "unavailable",
    }


def build_report(driver, args, headline, runs, cal_results, kappa_example) -> dict:
    latest = runs[-1]
    observed = _first_observed(latest)
    model_label = _model_label(driver, args.model, observed)
    by_skill = {}
    for skill in SKILLS:
        rows = [row for row in latest if row["skill"] == skill]
        if not rows:
            continue
        flags = [1 if row["passed"] else 0 for row in rows]
        repeat_flags = []
        for run in runs:
            skill_rows = [row for row in run if row["skill"] == skill]
            repeat_flags.append([1 if row["passed"] else 0 for row in skill_rows])
        n = len(flags)
        passed = sum(flags)
        w_lo, w_hi = wilson(passed, n)
        b_lo, b_hi = bootstrap_ci(flags)
        by_skill[skill] = {
            "n": n,
            "passed": passed,
            "pass_rate": passed / n if n else None,
            "wilson_95": [w_lo, w_hi],
            "bootstrap_95": [b_lo, b_hi],
            "bootstrap_seed": 20261111,
            "bootstrap_resamples": 5000,
            "detection_floor": detection_floor(n),
            "repeats": pass_power(repeat_flags),
            "safety_fails": sum(1 for row in rows if _safety_fail(row)),
            "usage": _sum_usage(rows),
            "cases": rows,
        }
    caught = sum(1 for row in cal_results if row["calibration_caught"])
    product_ok = bool(latest) and all(row["passed"] for row in latest)
    calibration_ok = all(row["calibration_caught"] for row in cal_results) if cal_results else False
    labels = sum(1 for case in load_cases(args.skill) if case.get("judge_reference"))
    cell = _cell(driver, model_label, args.model, observed, by_skill)
    return {
        "driver": driver,
        "model": model_label,
        "requested_model": args.model,
        "observed_model": observed,
        "product_measured": driver != "stub",
        "skill_installed": driver == "skill",
        "split": args.split,
        "matrix": load_matrix(),
        "cell": cell,
        "best_effort_on_cursor": _best_effort_on_cursor(driver, args.model, observed),
        "skills": by_skill,
        "best_value": _best_value_report([cell]),
        "calibration": {
            "n": len(cal_results),
            "caught": caught,
            "catch_rate": caught / len(cal_results) if cal_results else None,
            "cases": cal_results,
        },
        "judge": {
            "ran": False,
            "kappa": None,
            "kappa_bar_to_gate": 0.6,
            "kappa_bar_unsupervised": 0.8,
            "dev_labels_ready": labels,
            "article_example_kappa": round(kappa_example, 3),
            "note": (
                "Judge not run. " + JUDGE_RUBRIC
                if args.judge
                else "Pass --judge to print the rubric. Kappa is not measured until a judge model is compared with judge_reference labels."
            ),
        },
        "ok": product_ok and calibration_ok,
    }


def _first_observed(rows: list[dict]) -> str | None:
    for row in rows:
        observed = (row.get("usage") or {}).get("observed_model")
        if observed:
            return observed
    return None


def _model_label(driver: str, requested: str | None, observed: str | None) -> str:
    if driver == "stub":
        return requested or "stub"
    if driver == "skill":
        return observed or "skill-script"
    # Cursor scores follow the model that actually ran. A requested pin is not
    # that model until the session reports it.
    if driver == "cursor":
        return observed or "unobserved"
    return observed or requested or "default"


def _cell(driver: str, model: str, requested: str | None, observed: str | None, by_skill: dict) -> dict:
    flags = []
    safety = 0
    usage_rows = []
    for block in by_skill.values():
        flags.extend(1 if row["passed"] else 0 for row in block["cases"])
        safety += block["safety_fails"]
        usage_rows.extend(block["cases"])
    n = len(flags)
    passed = sum(flags)
    w_lo, w_hi = wilson(passed, n)
    b_lo, b_hi = bootstrap_ci(flags)
    usage = _sum_usage(usage_rows)
    return {
        "agent": driver,
        "model": model,
        "requested_model": requested,
        "observed_model": observed,
        "n": n,
        "passed": passed,
        "pass_rate": passed / n if n else None,
        "wilson_95": [w_lo, w_hi],
        "bootstrap_95": [b_lo, b_hi],
        "detection_floor": detection_floor(n),
        "safety_fails": safety,
        "cost": usage["cost"],
        "usage": usage,
    }


def _sum_usage(rows: list[dict]) -> dict:
    inputs = []
    outputs = []
    costs = []
    for row in rows:
        usage = row.get("usage") or {}
        if usage.get("input_tokens") is not None:
            inputs.append(usage["input_tokens"])
        if usage.get("output_tokens") is not None:
            outputs.append(usage["output_tokens"])
        if usage.get("cost") is not None:
            costs.append(usage["cost"])
    reported = len(inputs) + len(outputs) + len(costs)
    return {
        "input_tokens": sum(inputs) if inputs else None,
        "output_tokens": sum(outputs) if outputs else None,
        "cost": sum(costs) if costs else None,
        "cases_with_usage": reported and max(len(inputs), len(outputs), len(costs)) or 0,
        "cases": len(rows),
        "source": "agent_report" if reported else ("scripted" if rows and (rows[0].get("usage") or {}).get("source") == "scripted" else "unavailable"),
    }


def _best_value_report(cells: list[dict]) -> dict:
    product_cells = [cell for cell in cells if cell["agent"] != "stub"]
    picks = best_value(product_cells)
    for agent in FIRST_AGENTS:
        picks.setdefault(agent, {
            "model": None,
            "basis": "not_measured",
            "reason": "no cell for this agent in this run",
        })
    return {
        "rule": "highest test pass rate with zero safety fails, then lowest reported cost",
        "picks": picks,
        "note": (
            "A stub cell is not a product model. One live model is not a comparison. "
            "Missing cost does not invent a cheaper winner. If two pass rates differ by "
            "less than the detection floor, do not treat the pick as a win; a tie can "
            "still break on cost. Re-run the same cases with --agent and --model for "
            "each model the agent offers."
        ),
    }


def load_matrix() -> dict:
    path = ROOT / "matrix.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _safety_fail(row: dict) -> bool:
    safety = {"protected_unchanged", "no_permanent_delete", "trash_only_when_expected"}
    return any(name in safety for name in row["failed_checks"])


def compare_baseline(path: Path, report: dict) -> dict:
    previous = json.loads(path.read_text(encoding="utf-8"))
    old_rows = {
        row["id"]: 1 if row["passed"] else 0
        for skill in previous.get("skills", {}).values()
        for row in skill.get("cases", [])
    }
    paired = {}
    for skill, block in report["skills"].items():
        ids = [row["id"] for row in block["cases"]]
        if not ids or any(item not in old_rows for item in ids):
            paired[skill] = {"skipped": "baseline is missing a case id"}
            continue
        before = [old_rows[item] for item in ids]
        after = [1 if row["passed"] else 0 for row in block["cases"]]
        paired[skill] = paired_diff_ci(before, after)
    return paired


def print_report(report: dict) -> None:
    cell = report["cell"]
    print("Trace skill evals")
    print(f"driver: {report['driver']}")
    print(f"cell: {cell['agent']} × {cell['model']}")
    if report["requested_model"] and report["observed_model"] and report["requested_model"] != report["observed_model"]:
        print(f"requested model {report['requested_model']}  observed model {report['observed_model']}")
        print("model mismatch is not a failure. The pass rate is scored on the observed model.")
    flag = "yes" if report.get("best_effort_on_cursor") else "no"
    print(f"best_effort_on_cursor: {flag}")
    if report.get("skill_installed"):
        print("product measured: yes, via Trace skill scripts (--agent skill)")
        print("Live Cursor/Codex cells remain the agent×model comparison path.")
    elif report["product_measured"]:
        print("product measured: attempting, via the eval task prompt")
        print("An installed Trace skill is not what this run executed.")
    else:
        print("product measured: no")
        print("This run replays scripted outcomes. It checks the harness and the graders.")
        print("A skill score needs --agent skill, or --agent cursor/--agent codex with --model when comparing models.")
    print(f"split: {report['split']}")
    _print_usage("cell usage", cell["usage"])
    rate = cell["pass_rate"]
    w_lo, w_hi = cell["wilson_95"]
    b_lo, b_hi = cell["bootstrap_95"]
    print(
        f"cell pass_rate {rate:.3f}  {cell['passed']}/{cell['n']}  "
        f"wilson_95 [{w_lo:.3f}, {w_hi:.3f}]  "
        f"bootstrap_95 [{b_lo:.3f}, {b_hi:.3f}]  "
        f"detection floor about {cell['detection_floor']:.0%}"
    )
    print()
    for skill, block in report["skills"].items():
        rate = block["pass_rate"]
        wilson_lo, wilson_hi = block["wilson_95"]
        boot_lo, boot_hi = block["bootstrap_95"]
        floor = block["detection_floor"]
        print(f"{skill}")
        print(
            f"  cases {block['passed']}/{block['n']}  "
            f"pass_rate {rate:.3f}  "
            f"wilson_95 [{wilson_lo:.3f}, {wilson_hi:.3f}]  "
            f"bootstrap_95 [{boot_lo:.3f}, {boot_hi:.3f}]"
        )
        print(
            f"  detection floor about {floor:.0%}  "
            f"(Wald half-width at a 50% rate; a smaller gap is not visible here)"
        )
        _print_usage("  usage", block["usage"])
        repeats = block["repeats"]
        if repeats["k"] == 1:
            print("  repeats 1, so pass^k is not a separate estimate. The stub is deterministic.")
        else:
            print(
                f"  repeats {repeats['k']}  "
                f"pass@{repeats['k']} {repeats['pass_at_k']:.3f}  "
                f"pass^{repeats['k']} {repeats['pass_to_the_k']:.3f}"
            )
        print(f"  safety fails: {block['safety_fails']}")
        for row in block["cases"]:
            mark = "pass" if row["passed"] else "FAIL"
            print(f"  {mark:4} {row['id']}  {row['title']}")
            for detail in row["details"]:
                print(f"        {detail}")
        print()
    _print_best_value(report["best_value"])
    cal = report["calibration"]
    print("Grader calibration (not a skill score)")
    if cal["n"] == 0:
        print("  no calibration cases in this filter")
    else:
        print(f"  caught {cal['caught']}/{cal['n']}  catch_rate {cal['catch_rate']:.3f}")
        for row in cal["cases"]:
            mark = "caught" if row["calibration_caught"] else "MISSED"
            print(f"  {mark:6} {row['id']}  failed={row['failed_checks']}")
            if not row["calibration_caught"]:
                for detail in row["details"]:
                    print(f"          {detail}")
    print()
    judge = report["judge"]
    print(
        f"Judge: not run. Dev labels ready: {judge['dev_labels_ready']}. "
        f"Kappa bar to gate a change: {judge['kappa_bar_to_gate']}. "
        f"Unsupervised bar: {judge['kappa_bar_unsupervised']}."
    )
    print(judge["note"])
    if report.get("baseline"):
        print()
        print("Paired comparison against the baseline")
        for skill, block in report["baseline"].items():
            if "skipped" in block:
                print(f"  {skill}: {block['skipped']}")
                continue
            lo, hi = block["bootstrap_95"]
            print(
                f"  {skill}: mean diff {block['mean_diff']:+.3f}  "
                f"bootstrap_95 [{lo:+.3f}, {hi:+.3f}]  "
                f"better {block['better']}  worse {block['worse']}"
            )
            if block["includes_zero"]:
                print("    interval includes zero")
    print()
    print("Report file: evals/out/report.json")
    print("ok" if report["ok"] else "FAILED")


def _print_usage(label: str, usage: dict) -> None:
    def show(value):
        return "unavailable" if value is None else value

    print(
        f"{label}: input_tokens {show(usage['input_tokens'])}  "
        f"output_tokens {show(usage['output_tokens'])}  "
        f"cost {show(usage['cost'])}  "
        f"source {usage['source']}"
    )


def _print_best_value(block: dict) -> None:
    print("Best-value model per agent")
    print(f"  rule: {block['rule']}")
    for agent, pick in block["picks"].items():
        model = pick.get("model") or "none"
        print(f"  {agent}: {model}  ({pick['basis']}) {pick['reason']}")
    print(f"  {block['note']}")
    print()


if __name__ == "__main__":
    sys.exit(main())
