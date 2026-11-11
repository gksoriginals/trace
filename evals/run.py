#!/usr/bin/env python3
"""Run Trace skill evals and print a report.

Default driver is automatic: Claude Code if `claude` is on PATH, otherwise
Codex if `codex` is on PATH, otherwise the stub. The stub replays a scripted
outcome so this command finishes with no agent installed. Calibration cases
always use the stub. They are planted failures, and a live agent that behaved
well would hide a grader bug.

This is not a CI gate. See docs/evals.md.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from harness.drivers import JUDGE_RUBRIC, DriverError, apply_stub, render_prompt, run_live, select_driver
from harness.graders import failed_names, grade
from harness.stats import (
    article_kappa_example,
    bootstrap_ci,
    detection_floor,
    paired_diff_ci,
    pass_power,
    wilson,
)
from harness.workspace import materialize


SKILLS = (
    "hygienic_setup",
    "session_end",
    "memory_writer",
    "decide_later",
    "ask_trace",
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run Trace skill outcome evals")
    parser.add_argument("--agent", default="auto", choices=("auto", "stub", "claude", "codex"))
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
    calibration = [c for c in cases if c["split"] == "calibration"]
    tasks = {skill: (ROOT / "tasks" / f"{skill}.md").read_text(encoding="utf-8") for skill in SKILLS}

    runs: list[list[dict]] = []
    for _ in range(args.repeats):
        runs.append([
            run_case(case, driver, tasks[case["skill"]], args.timeout, planted=False)
            for case in headline
        ])
    cal_results = [
        run_case(case, "stub", tasks.get(case["skill"], ""), args.timeout, planted=True)
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


def run_case(case: dict, driver: str, task: str, timeout: int, planted: bool) -> dict:
    fixture = case["fixture"]
    expected = case["expected"]
    with tempfile.TemporaryDirectory(prefix="trace-eval-") as tmp:
        workspace = Path(tmp)
        materialize(fixture, workspace)
        driver_note = ""
        usage = None
        try:
            if planted or driver == "stub":
                apply_stub(case.get("stub_result") or {}, workspace)
                driver_note = "stub"
            else:
                prompt = render_prompt(task, fixture)
                usage = run_live(driver, prompt, workspace, timeout)
                driver_note = driver
            checks = grade(fixture, expected, workspace)
        except (DriverError, OSError, json.JSONDecodeError) as exc:
            return {
                "id": case["id"],
                "skill": case["skill"],
                "split": case["split"],
                "title": case.get("title", ""),
                "passed": False,
                "failed_checks": ["driver_error"],
                "details": [f"driver_error: {exc}"],
                "driver": driver_note or driver,
                "expect_fail_checks": case.get("expect_fail_checks") or [],
                "calibration_caught": False,
                "usage": None,
            }
    failed = failed_names(checks)
    passed = not failed
    expected_fail = case.get("expect_fail_checks") or []
    caught = (not passed) and all(name in failed for name in expected_fail)
    return {
        "id": case["id"],
        "skill": case["skill"],
        "split": case["split"],
        "title": case.get("title", ""),
        "passed": passed,
        "failed_checks": failed,
        "details": [f"{c.name}: {c.detail}" for c in checks if not c.passed],
        "driver": driver_note,
        "expect_fail_checks": expected_fail,
        "calibration_caught": caught if case["split"] == "calibration" else None,
        "usage": _usage_note(usage),
    }


def _usage_note(text: str | None) -> str:
    if not text:
        return "unavailable"
    for key in ("total_cost_usd", "input_tokens", "output_tokens"):
        if key in text:
            return "reported in agent stdout; see the captured run if you need the figure"
    return "unavailable"


def build_report(driver, args, headline, runs, cal_results, kappa_example) -> dict:
    latest = runs[-1]
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
            "cases": rows,
        }
    caught = sum(1 for row in cal_results if row["calibration_caught"])
    product_ok = bool(latest) and all(row["passed"] for row in latest)
    calibration_ok = all(row["calibration_caught"] for row in cal_results) if cal_results else False
    labels = sum(1 for case in load_cases(args.skill) if case.get("judge_reference"))
    return {
        "driver": driver,
        "product_measured": driver != "stub",
        "skill_installed": False,
        "split": args.split,
        "skills": by_skill,
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
    print("Trace skill evals")
    print(f"driver: {report['driver']}")
    if report["product_measured"]:
        print("product measured: attempting, via the eval task prompt")
        print("An installed Trace skill is not what this run executed.")
    else:
        print("product measured: no")
        print("This run replays scripted outcomes. It checks the harness and the graders.")
        print("A skill score needs --agent claude or --agent codex.")
    print(f"split: {report['split']}")
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


if __name__ == "__main__":
    sys.exit(main())
