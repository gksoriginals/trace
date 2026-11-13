# ADR-0009: Git-aware worktree flow (Trash + prune + repair)

- **Status:** accepted
- **Date:** 2026-11-13
- **Deciders:** Gopi

## Context

PRD §8.4 keeps dirty, untracked, unmerged, linked, or uncertain worktrees protected pending a dedicated Git-aware flow. A manual Ally cleanup on 13 November 2026 showed concrete checks that flow needs, and a safety trap: `git worktree remove` deletes ignored files permanently and bypasses Trash (firm rule). Field notes from that run were development input only; this ADR is the decision record.

A disposable-repo spike tested recovery:

1. Moving the worktree directory to Trash, then `git worktree prune`, drops the linked tree from `git worktree list` and keeps the branch ref.
2. `git worktree repair <path>` after prune **fails** if the admin dir (`.git/worktrees/<name>/`) was pruned away — the restored tree's `.git` file points at a missing gitdir.
3. Undo works when the skill journals and restores that admin dir alongside the Trash restore, then runs `repair`. `prune` while the tree is present leaves it linked.

## Decision

Session-end proposes a linked worktree for Trash only when every check below passes. Candidates come from `git worktree list --porcelain`, never from path patterns.

```
candidate worktree W
  ├─ primary checkout or locked?                 → keep (protected)
  ├─ fetch remote default branch
  │    └─ fetch failed?                          → Decide-later: merge-unknown
  ├─ merged? ancestor of origin/<default>
  │    or patch-id equivalent (git cherry)       → no: keep (ordinary)
  ├─ clean? status --porcelain empty             → no: Decide-later: worktree-dirty
  ├─ in use? process cwd/argv under W
  │    (ps + lsof cwd; unknown ⇒ keep)           → yes/unknown: Decide-later: worktree-in-use
  ├─ ignored files: regenerable, byte-identical
  │    to primary, or absent                     → no: Decide-later: worktree-unique-ignored
  └─ propose remove merged worktree
        on consent: re-check at the boundary (PRD §8.3)
                    → journal path, branch, head sha, admin dir (copy)
                    → move W to Trash
                    → git worktree prune
        undo:       restore W from Trash + restore admin dir → git worktree repair
        branch ref: optional separate proposal; record merge proof in memory
```

**Merged** means: after a successful fetch, reachable from the remote default branch (ancestor test), with patch-id equivalence as fallback for squash/rebase merges. Record which test proved it and the fetch time. Offline/auth fetch failure ⇒ merge-unknown, not false.

**Removal** never uses `git worktree remove` or `rm`. Trash only. Ignored secrets stay protected.

**Hygienic setup** (when an agent creates a worktree): before install, compare lockfile hashes with the primary checkout. Prefer shared store, then APFS clone (`cp -c`); never symlink `node_modules`. Ask first (ADR-0002). Memory: `kind = dependencies`, `can_go_when = "worktree removed"`. APFS clone vs shared store preference is a current guess, not a firm rule.

## Consequences

- Eval harness gains `fixture.git` and optional process fixtures; new cases live in the **dev** split (`se-dev-05`…, `hs-dev-05/06`, `at-dev-05/06`) until deliberately promoted.
- Skills must refuse host `--force` worktree removal; least-privilege one-item commands are the default.
- Report-only container items (PRD §8.5) use `trace-out/report.json` per [ADR-0010](0010-report-only-channel.md), not Decide-later.
- Never-delete patterns expand toward `*.env`, `id_*` without `.pub`, and light content sniffing (separate skill change; seeded by `se-dev-12`).

## What would change it

Evidence that admin-dir journaling is unreliable across git versions, or a Trash API that cannot restore a directory tree with its `.git` gitdir file intact. A measured dogfood failure where patch-id equivalence mis-classifies unmerged work.
