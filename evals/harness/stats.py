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
