"""Intervals and agreement for skill-eval reports.

The Wilson interval stays informative when every case passes. The bootstrap
interval is the one to compare two runs on the same cases. The kappa helper
is checked against the worked example in the eval article (about 0.15).
"""

from __future__ import annotations

import math
import random


def wilson(successes: int, n: int, z: float = 1.96) -> tuple[float, float] | tuple[None, None]:
    if n <= 0:
        return (None, None)
    p = successes / n
    z2 = z * z
    denom = 1 + z2 / n
    centre = (p + z2 / (2 * n)) / denom
    margin = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / denom
    return (max(0.0, centre - margin), min(1.0, centre + margin))


def bootstrap_ci(
    flags: list[int],
    n_boot: int = 5000,
    seed: int = 20261111,
) -> tuple[float, float] | tuple[None, None]:
    if not flags:
        return (None, None)
    rng = random.Random(seed)
    n = len(flags)
    means = []
    for _ in range(n_boot):
        total = 0
        for _ in range(n):
            total += flags[rng.randrange(n)]
        means.append(total / n)
    means.sort()
    lo_i = int(round(0.025 * (n_boot - 1)))
    hi_i = int(round(0.975 * (n_boot - 1)))
    return (means[lo_i], means[hi_i])


def paired_diff_ci(
    before: list[int],
    after: list[int],
    n_boot: int = 5000,
    seed: int = 20261111,
) -> dict:
    if len(before) != len(after) or not before:
        raise ValueError("paired comparison needs two equal non-empty lists")
    diffs = [a - b for b, a in zip(before, after)]
    rng = random.Random(seed)
    n = len(diffs)
    means = []
    for _ in range(n_boot):
        total = 0.0
        for _ in range(n):
            total += diffs[rng.randrange(n)]
        means.append(total / n)
    means.sort()
    lo_i = int(round(0.025 * (n_boot - 1)))
    hi_i = int(round(0.975 * (n_boot - 1)))
    better = sum(1 for b, a in zip(before, after) if b == 0 and a == 1)
    worse = sum(1 for b, a in zip(before, after) if b == 1 and a == 0)
    return {
        "n": n,
        "mean_diff": sum(diffs) / n,
        "bootstrap_95": [means[lo_i], means[hi_i]],
        "better": better,
        "worse": worse,
        "includes_zero": means[lo_i] <= 0.0 <= means[hi_i],
    }


def detection_floor(n: int) -> float | None:
    """Half-width of a Wald interval at a 50% rate. Rough, and printed as such."""
    if n <= 0:
        return None
    return 1.96 * math.sqrt(0.25 / n)


def cohen_kappa(left: list[int], right: list[int]) -> float:
    if not left or len(left) != len(right):
        raise ValueError("kappa needs two equal non-empty label lists")
    n = len(left)
    agree = sum(1 for a, b in zip(left, right) if a == b)
    p_o = agree / n
    p_left = sum(left) / n
    p_right = sum(right) / n
    p_e = p_left * p_right + (1 - p_left) * (1 - p_right)
    if p_e == 1:
        return 1.0
    return (p_o - p_e) / (1 - p_e)


def article_kappa_example() -> float:
    """The article's judge: 26 both pass, 8 reference-only, 10 both fail, 16 judge-only.

    Those four cells are the unique non-negative solution of the article's
    totals (34 reference passes, 42 judge passes, 36 agreements, out of 60),
    and they produce kappa of about 0.15.
    """
    reference = [1] * 26 + [1] * 8 + [0] * 10 + [0] * 16
    judge = [1] * 26 + [0] * 8 + [0] * 10 + [1] * 16
    return cohen_kappa(reference, judge)


def pass_power(runs: list[list[int]]) -> dict:
    """runs is a list of k flag-lists, one per repeat, aligned by case.

    pass_at_k is the share of cases with at least one pass.
    pass_to_the_k is the share of cases that passed every repeat.
    """
    if not runs:
        return {"k": 0, "n": 0, "pass_at_k": None, "pass_to_the_k": None}
    k = len(runs)
    n = len(runs[0])
    at_least = 0
    every = 0
    for i in range(n):
        flags = [repeat[i] for repeat in runs]
        if any(flags):
            at_least += 1
        if all(flags):
            every += 1
    return {
        "k": k,
        "n": n,
        "pass_at_k": at_least / n,
        "pass_to_the_k": every / n,
    }


def best_value(cells: list[dict]) -> dict:
    """Pick a model per agent. Quality first, then cost.

    A cell needs agent, model, pass_rate, safety_fails, and cost (a number
    or None). A safety miss is out. Among the rest, the higher pass rate
    wins. Equal pass rates go to the lower cost when both costs are numbers.
    One measured model is reported as the only candidate, not as a comparison.
    Missing cost never invents a cheaper winner.
    """
    by_agent: dict[str, list[dict]] = {}
    for cell in cells:
        by_agent.setdefault(cell["agent"], []).append(cell)
    picks = {}
    for agent, group in by_agent.items():
        eligible = [cell for cell in group if cell.get("safety_fails", 0) == 0 and cell.get("pass_rate") is not None]
        if not eligible:
            picks[agent] = {
                "model": None,
                "basis": "withheld",
                "reason": "no measured model with zero safety fails",
            }
            continue
        def sort_key(cell: dict) -> tuple:
            cost = cell.get("cost")
            # Higher pass rate first. Known costs sort after the rate; a
            # missing cost sorts last so it cannot beat a priced tie.
            missing = cost is None
            return (-float(cell["pass_rate"]), missing, float(cost) if not missing else 0.0)

        ordered = sorted(eligible, key=sort_key)
        winner = ordered[0]
        costs_known = [cell.get("cost") for cell in eligible if cell.get("cost") is not None]
        if len(eligible) == 1:
            basis = "only_model"
            reason = "only model measured for this agent; not a comparison"
        elif winner.get("cost") is None:
            basis = "quality_only"
            reason = "highest pass rate; cost was not reported, so this is not a cost pick"
        elif len(costs_known) < len(eligible):
            basis = "quality_then_partial_cost"
            reason = "highest pass rate, then lower cost where a cost was reported"
        else:
            basis = "quality_then_cost"
            reason = "highest pass rate, then lowest reported cost"
        picks[agent] = {
            "model": winner["model"],
            "pass_rate": winner["pass_rate"],
            "cost": winner.get("cost"),
            "basis": basis,
            "reason": reason,
        }
    return picks
