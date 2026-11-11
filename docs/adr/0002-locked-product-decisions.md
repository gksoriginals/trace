# ADR-0002: Locked product decisions

- **Status:** accepted
- **Date:** 2026-11-11
- **Deciders:** Gopi

## Context

PRD v0.2 and the engineering direction left ten product choices open: how much a skill may do on its own, install scope, budgets, the 70% metric, where files live, background work, distribution, which agents come first, how a model is chosen, and the minimum macOS version. Design and onboarding still described token budgets and a macOS 13 candidate. Those conflicted with a decision, so they are updated in the same change. This record locks the choices. It does not replace ADR-0001.

## Decision

1. **Skill autonomy.** Skills run inside the coding agent while it works. Before any cleanup or install, the skill nudges the user and asks. It looks up the healthiest, most efficient way to do the job and adds the steps to that agent's own task checklist. It records the user's decision in project memory and follows it next time. It may remove something without asking again only when the user approved that exact item before. Everything else is asked about, or goes to Decide-later.
2. **Install scope.** Whole agent by default, with a per-project opt-out.
3. **Budgets.** None for now. Coding agents mostly run on subscription quota. Trace does not set a token or time cap. It shows what each Run or Ask used. Memory is still tried first. Caps can be revisited later.
4. **70% target.** The share of bytes from agent-created artifacts that are removed within 30 days of creation. Shared caches count once. Measured free space is always shown separately and is never the metric.
5. **Storage.** Everything stays on the Mac. Skills append to a per-project log. The app is the only writer of its database. Skills also keep an index of projects and where their memory files are, so the app can point a coding-agent session at each project's memory. The index path and schema in the engineering doc are directional.
6. **Background runs.** Only while the menu bar app is running. No helper process continues after quit.
7. **Distribution.** Local dogfood only for now. The auth path, the distribution path, and the public name are decided at M2. Codex app-server auth is acceptable for this local dogfood. Its commercial limits are an M2 question.
8. **First agents.** Cursor, over ACP, and Codex, over app-server. Claude and Gemini are later adapters.
9. **Models.** Trace cannot always pick the model. For an app-triggered run the user picks the coding agent. Skills are evaluated across that agent's available models, and the best-value model per agent is the one that wins on quality against cost. If only some models handle a skill well, the skill pins that model and tells the agent to run the skill in a subagent on it.
10. **Minimum macOS** is 14.

## Consequences

Token and time budget controls leave onboarding, Settings, Run, and Ask. Usage replaces them. The first spikes and the eval drivers target Cursor and Codex. The eval report is one agent×model cell at a time and names a best-value pick only when a real comparison exists. The app database and the skill logs are different files with different writers. A scheduled review, if the user turns it on, dies with the app.

Firm rules in the engineering doc now include these ten. Module names, the index's exact path, timeout numbers, and which model actually wins remain guesses.

## What would change it

A dogfood result that subscription quota makes an uncapped Run unusable, which would reopen caps. A measured miss that in-session asking blocks the work the skills are for. Evidence that Cursor ACP or Codex app-server cannot hold a two-way session on Gopi's machine, which would reopen the first-agent choice. A decision at M2 on auth, distribution, or the public name, which this record already schedules. A best-value pick from a live eval, which fills decision 9 without reopening the rule.
