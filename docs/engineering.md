# Trace — engineering direction

**Status:** directional. This is not a locked architecture. **Owner:** Gopi · **Date:** 11 November 2026

Companion to [PRD v0.2](prd.md) and [Design & UX v0.2](design.md). The PRD owns scope and safety. The design owns presentation. This document names the pieces and the data they share. Gopi locked the product choices in [ADR-0002](adr/0002-locked-product-decisions.md). When a guess below changes, record it in [docs/adr/](adr/).

Checked against official agent docs on 11 November 2026. Those capabilities are documented, not device-tested on Gopi's Mac. `gksoriginals/shed` returned 404 from this environment; Shed lessons below are the ones the PRD kept after reading that archive.

## How to read this

Two kinds of decision sit in this document.

**Firm rules.** Changing one of these is a product decision, an ADR, and usually a safety or eval change. They are listed in the next section and repeated only where a module has to enforce them.

**Current guess, change freely.** Names of modules, file paths (including the index path below), screen composition, timeout numbers, which specific model wins a comparison, and the order of work inside a milestone are guesses. They exist so the first spike has something to build. They are not acceptance tests. If a spike shows a better shape, change it and write an ADR. Do not add tests that freeze a guess. The rule for how a model is chosen is firm. The winning model id is not.

## Firm rules

1. **Trash only.** Move eligible filesystem items to the Trash. Never permanently delete. Never empty the Trash. Never Trash a tool's VM disk or a package store's internals to imitate a supported prune. Tool-native removal that cannot be restored stays report-only until a separate recovery design exists.
2. **Never-delete list.** System trees and volume roots; Documents, Photos, and Mail; secrets and credentials; primary source checkouts and original or only-copy data; plus the user's editable never-touch list. A protected ancestor is not a bulk cleanup target. A generated artifact inside a repository is judged on its own. Unknown means keep.
3. **One confirmation, then a fingerprint check.** The user confirms one immutable selection. Immediately before Trash, re-check identity, fingerprint, source state, and current use. A changed item is skipped and shown again. If the check cannot finish, do nothing.
4. **No silent removal.** A skill asks before a removal that was not already exactly approved. Doubt, shared consumers, or a source of truth go to Decide-later. Age, a familiar folder name, `.gitignore`, or a model's confidence is not a reason to remove.
5. **Memory log format.** The version 1 field contract in [Memory log](#memory-log) is the format skills and the app share. The log is append-only. A correction is a new event. Additive optional fields are allowed. Renaming, removing, or changing the meaning of a field bumps the version and needs an ADR.
6. **Two-way sessions for app-agent work.** Run and agent-tier Ask use a persistent, resumable, bidirectional session: streaming, follow-up messages, permission replies, explicit terminal states, deadlines, and cancellation that kills the owned process group. A one-shot process that leaves the UI guessing is not a fallback.
7. **Evals first.** Skill-outcome evals and safety checks are the tests written up front. No UI tests and no tests of internal design until that part has stayed stable. See [Testing rule](#testing-rule) and [evals.md](evals.md).
8. **Credentials stay in the agent.** Trace never reads, copies, or parses credential files, session tokens, or keychains to make an integration work. An adapter whose terms or login are not met stays unavailable. Skills and local Home keep working.
9. **Local, and quiet.** The ledger, queue, registry, settings, and logs stay on the Mac. No telemetry by default. No cloud memory sync.
10. **Memory before a coding agent.** Ask answers from project memory first. A hosted model runs only after the user accepts an agent and a scope. Ask is read-only: it can propose an action card and cannot execute one.
11. **Skill autonomy.** A skill runs inside the coding agent while it works. Before any cleanup or install, it nudges the user and asks. It looks up the healthiest, most efficient way and adds those steps to that agent's own task checklist. It records the decision in project memory and follows it next time. It may remove something without asking again only when the user approved that exact item before. Everything else is asked about, or goes to Decide-later.
12. **Install scope.** Whole agent by default. A project can opt out. A project-only install is not the default, and it is not a broken setup when the user opted that project out.
13. **No Trace caps for now.** Coding agents mostly run on subscription quota. Trace sets no token cap and no time cap on a Run or an Ask. It shows the usage the agent reported for that Run or Ask, or "unavailable." Memory-only answers spend none of that. Caps can be revisited later. This replaced the budget settings.
14. **The 70% metric.** The share of bytes from agent-created artifacts that are removed within 30 days of creation. Shared caches count once. Measured free space is shown beside it and is never the percentage. Bytes whose creator is unknown stay out of both sides and are reported as unknown.
15. **Local storage, split writers.** The ledger, queue, index, settings, and logs stay on the Mac. Skills append to a per-project log. The app is the only writer of its database. Skills keep the project index. No telemetry by default. No cloud memory sync.
16. **Background only while the app is running.** A review the user opted into runs only while the menu bar app is running. Quit ends it. There is no helper process after quit, and no scheduled Execute.
17. **Local dogfood only.** Auth, distribution, and the public name are decided at M2. Until then Trace is a local build on Gopi's Mac. Codex app-server auth is acceptable for that dogfood. Its ban on commercial or hosted use is an M2 question, not a reason to block the spike.
18. **First agents.** Cursor over ACP, and Codex over app-server. Claude and Gemini are later adapters. The eval harness and the throwaway spikes follow that order.
19. **Models.** Trace cannot always choose the model. For an app-triggered run the user picks the coding agent. The evals compare that agent's available models and name a best-value model per agent (quality, then cost). If only some models handle a skill well, the skill pins that model and tells the agent to run the skill in a subagent on it.
20. **Minimum macOS is 14.**

Conservative defaults are part of the safety rules: shared, unknown, protected, and prior-regret items are not preselected.

## Testing rule

This is the rule in [agent.md](../agent.md), restated so an implementation change does not drift from it.

- Write skill evals and safety checks. The harness lives in [`evals/`](../evals/) and the method lives in [evals.md](evals.md).
- Do not write UI tests, and do not write tests that lock internal design, until that part has stayed stable through dogfood.
- After two failed fix attempts in a loop, stop and report. Do not weaken a grader or a fixture to make the loop green.
- Treat everything outside the firm rules as a current guess. Record a pivot in `docs/adr/`.

The evals grade what a skill achieves on a fixture: storage it created is cleaned up or recorded, protected paths are untouched, nothing is deleted without a yes, and memory entries are complete and accurate. They do not grade how the skill is written.

## Split of work

Skills do the everyday work inside the coding agent, while the user is still in the session that created the storage. The app configures that behavior, shows the outcome, and handles doubt. Opening Home does not start a model call or a scan.

| Piece | Who runs it | What it does | What it refuses to be |
| --- | --- | --- | --- |
| **Hygienic setup** | Skill, in the coding agent | Before a build, install, environment, container, model, or dataset, nudge the user and ask. Look up the healthiest current practice for that tool version, and add the steps to the agent's own task checklist. Do the setup the user just approved, or the one they approved for this exact item before. Avoid a needless copy. Record the decision and what changed: why, where, how to recreate or reverse it, and which project depends on it. | A silent install, or a blanket "containers are always smaller." |
| **Session-end cleanup** | Skill, in the coding agent | While the session is still the one that created the files, nudge the user before a removal. Propose short-lived files. Move something to Trash without asking again only when the user approved that exact item before. | A delete that happens because the session ended. |
| **Memory writer** | Skill, in the coding agent | Append compact events: artifacts, setup changes, cleanup outcomes, coverage receipts, and a few evidence-backed lessons. | A second summary universe, or a dump of every command. |
| **Decide-later** | Any skill writes it; Home shows it | A durable local queue item when a storage decision is doubtful. | A notification counter, or a timer that deletes when it expires. |
| **Setup** | App | Agents and whether the CLI is installed, the version, and sign-in as verified or unknown. Opt-in skills. Whole-agent install, with a per-project opt-out. Project roots and categories. Guardrails and lifecycle. No budget fields. | A whole-disk permission wizard, a budget form, or setup again before every run. |
| **Home** | App | Decide-later at the top. Then one insight card per project: what Trace did, setup changes that matter, storage outcomes, coverage. Read local records only. | A Run screen, a file inventory, or a transcript feed. |
| **Ask Trace** | App | One question surface. Memory first. The coding agent only when memory is not enough, and only after the user accepts the agent and the scope. Show the usage that call reported. | A general chatbot, a budget gate, or a way to execute cleanup from chat. |
| **Run** | App, on demand | Three stages: **Reviewing**, then **Actions** (cards), then **Execute**. The user picks the coding agent. Uses memory, then a targeted catch-up where coverage has a gap. Shows usage as the agent reports it. There is no token cap. Costs more of the subscription quota than a skill, which is why it stays on demand. | The way everyday cleanup happens, a capped job, or a refresh on every app open. |

Skills work with the app closed. They share Trash, the never-delete list, and the journal through a small local action boundary, so a skill does not need a window open to move an already-approved path to Trash.

Run's three stages, in order:

1. **Reviewing** plans and inspects the selected projects with the chosen agent and the memory already on disk. It replays a missing skill in inspection and proposal mode. It does not repeat an install or a cleanup that the journal already recorded.
2. **Actions** replaces a file list with cards. One card is one operation, with size, safety, who did it, and whether it can be undone. The user selects. Shared, unknown, protected, and prior-regret cards start unselected.
3. **Execute** takes that exact selection as the single consent. Native code re-checks fingerprints and moves eligible items to Trash. The agent does not get to invent a delete command or a new target.

M0 is skills and the queue, reviewed in the coding agent. M1 adds Setup, Home, and memory-only Ask; the first inspection is already a two-way session, and the app does not execute cleanup yet. M2 adds the full Run and agent-tier Ask.

## Components

These names are the vocabulary for spikes and ADRs. The grouping is a current guess.

| Name | Role |
| --- | --- |
| Hygienic setup, Session-end cleanup, Memory writer | The three skills. One job each. |
| Decide-later queue | Durable doubtful decisions. Writers: skills, and later Reviewing. Reader: Home. |
| Memory log | Append-only provenance ledger. The app does not keep a parallel summary. |
| Project registry | Stable project ids, roots, categories, shared-store notes. |
| Settings | Opt-in skills, whole-agent install with per-project opt-out, never-touch list, retention, notifications. No budget fields. |
| Coverage receipts | Per project, per agent, per skill version: completed, partial, or failed, and which session range. |
| Action journal | What was confirmed, the fingerprint at confirm time, what reached Trash, what was skipped. |
| Session checkpoint | Ids needed to resume one Trace conversation. Not a filesystem snapshot. |
| Home reader | Renders the queue and insight cards from local stores. |
| Ask Trace | Retrieval over the log and notes, then an optional agent tier. |
| Run conductor | Reviewing, action cards, the consent boundary, Execute. |
| Trash service | The only component that moves files to Trash. Native. The agent talks to it through the action boundary, or not at all. |
| Agent adapter | One implementation per harness. See [Adapter interface](#adapter-interface). |
| Session supervisor | Owns the live process: spawn, stream, deadlines, interrupt, drain, process-group kill, checkpoint. |

Design-doc card names (`TraceInsightCard`, `DecideLaterCard`, `TraceActionCard`) are presentation. They are not modules to freeze.

## Data model

The product's memory stays on the Mac. Skills and the app do not share a database.

- **Per-project log.** Skills append. The app reads. It does not invent a second history.
- **Project index.** Skills write it. The app reads it to find each project's log and to point a coding-agent session at that memory.
- **App database.** The app is the only writer. Skills never open it. Settings, the action journal, session checkpoints, and Home's imported snapshot live here.

Receipts can live in the per-project log. The directory names below are a guess. The split of writers is not.

Concurrent skill sessions appending to one log are still a guess: open the file append-only, and surface a torn line instead of last-write-wins. Two skills do not take turns writing the app database, because they do not write it at all.

Schema version lives on every record. A reader accepts the current version and the previous one. An unknown version is refused and shown, not guessed.

### Memory log

Version 1. One JSON object per line. Firm fields:

| Field | Required content |
| --- | --- |
| `schema_version` | `1` |
| `event_id` | Stable id. Never reused. |
| `event_type` | `artifact`, `setup_change`, `cleanup_outcome`, `coverage_receipt`, `correction`, `lesson`, or `decision` |
| `what` | `id`, `kind`, `location` (canonical path or a tool-native id). `bytes` and `completeness` (`known`, `partial`, `unknown`) when the skill actually measured them. Unknown stays null, not zero. |
| `why` | The task, and why it should stay or why it is temporary. |
| `claim` | `observed`, `inferred`, or `verified`. |
| `agent` | `harness` and `session_id`. Use `unknown` when attribution is not real. |
| `project` | `id`, plus `consumers` for a shared resource. Uncertainty stays in the list as unknown, not as an empty "nobody uses this." |
| `created` | `at` (timestamp with zone), `source` (`observed`, `inferred`, or `discovered`). Discovery on a first review is not back-dated into a fake creation. |
| `can_go_when` | A condition, such as "task finished and no remaining consumers." Never "it is old." |
| `evidence_ids` | Pointers to session evidence the user allowed, or to earlier events. |
| `correction_of` | The earlier `event_id`, or null. The earlier event stays in the file. |

A setup recipe is redacted. It explains how to recreate the change and does not contain a secret or a command the app is allowed to run. A lesson carries its evidence, the conditions, and the last time it was checked. A failed guess does not become a rule by being written down.

A `decision` event is the user's answer for one exact item: approved this install, approved this removal, kept, or deferred. The next session follows it. An approval names the item. It is not a standing yes for a folder pattern the user never saw.

Live size is remeasured when someone asks. It is not stored as a permanent belief.

The log is advisory. It does not override a protected path, a current dependency, or a missing yes.

### Decide-later queue

Version 1. One record per doubt, deduplicated by `id`. A repeated observation updates evidence and `last_observed`. It does not add a second item or a second notification.

| Field | Meaning |
| --- | --- |
| `schema_version` | `1` |
| `id` | Stable. |
| `project_id`, `agent`, `session_id` | Where the doubt came from. |
| `artifact_id`, `action` | The thing and the action that is not safe to take. |
| `why_doubtful` | The specific uncertainty. |
| `bytes`, `completeness` | Known size, or null and `unknown`. |
| `evidence_ids` | What the skill already looked at. |
| `would_resolve` | The fact that would make this decidable. |
| `first_observed`, `last_observed` | Timestamps with zone. |
| `status` | `open`, `planned`, `deferred`, `kept`, `resolved`, `stale`. |

Nothing is deleted because a row is old, stale, or deferred. `planned` routes into Run's Actions; it is not consent. A resolved row stays in history with its outcome.

### Project registry

Version 1 is a guess in its extra fields. The stable `id` is the part Ask, memory, and Home join on. A renamed directory does not mint a new project; the user locates the root again.

A project record holds display name, selected roots, which categories are in scope (caches, builds and environments, worktrees, containers, models, project data — all on means inspect, not delete), opt-out from the whole-agent install, and notes for shared stores: known consumers, evidence date, recreation cost, and an explicit unknown. Shared bytes are counted once.

### Project index

Skills keep this file so the app can point a coding-agent session at each project's memory without opening the app database. Location and field names are a current guess:

- Path: `~/.trace/index.json`. It is outside the app database on purpose, and it exists before the app is installed. The app reads it. Skills replace it atomically (write a temp file, then rename).
- Shape: `schema_version` 1, and `projects`, a list of `{id, display_name, roots, memory_log, opt_out, updated_at}`. `memory_log` is the absolute path of that project's append-only log. The first guess for the log is `<project-root>/.trace/memory.jsonl`.
- The app's database is the other guess: `~/Library/Application Support/Trace/trace.db`. Only the app process writes it.

A skill that sees a project for the first time adds or updates that project's index row, then appends to the log. It does not create the database.

### Settings

One local document, inside the app database. It holds opted-in skills, the whole-agent default, the per-project opt-out list, the never-touch list, category scope, memory-retention preference, menu-bar and Decide-later notification opt-in, and the optional review schedule, which is off and runs only while the app is running. Appearance and the Freed sound live here too. There is no Run budget and no Ask budget.

A signed-in CLI is recorded as a status the adapter reports (`ready`, `unknown`, `unsupported`, `terms_unmet`). The status is not a copy of a token.

### Supporting records

**Coverage receipt.** Project, agent, skill name, skill version, start, end, state (`completed`, `partial`, `failed`), and the session or event range covered. An old timestamp by itself is not a gap. A known session with no completed receipt is a gap. Unknown is labelled unknown.

**Action journal.** Selection id, each path or tool id, fingerprint at confirm time, fingerprint immediately before the move, Trash destination, outcome (`moved`, `skipped`, `failed`), and why. Execute is disabled when the journal cannot be written. Undo restores only journaled Trash items, and never overwrites a destination that now exists.

**Session checkpoint.** Project, agent, the model the user or the skill pinned, protocol version, session or thread or turn ids, last handled event cursor, scope and policy hash, pending request ids, and the usage reported so far. Resume uses this. Resume does not replay Execute or a previous approval, and it does not consult a remaining allowance, because there is none.

## Main logic

### During a coding session

Hygienic setup runs before the agent creates storage. It asks, looks up the current practice, and puts the steps on the agent's own checklist (Cursor, Codex, and Claude each keep one; the skill uses whichever list that session already has). It records the location it actually used and the decision the user made. Session-end cleanup runs while that session still has the context. It asks before a removal, writes proposals and queue items, and moves a path to Trash through the action boundary only when the user approved that exact item before. The memory writer appends events for all of that, including the decision. The app can be closed the whole time. The skill updates the project index if this project is new.

### Home

Read the queue, the log, receipts, and the journal. Group insight cards by project. Badge each event as skill, app run, or the user. Keep and defer on a queue item are local writes with no model call. A removal still has to become an action card and pass Execute.

### Ask Trace

Described in [Ask Trace](#ask-trace). Memory retrieval is a local read. Agent escalation opens the session supervisor.

### Run

The user picks a project and a coding agent. Reviewing streams factual milestones into a checkpointed session and shows usage as it is reported. There is no allowance to accept first. Actions are built from memory plus what Reviewing just verified. Execute freezes the selection, re-checks fingerprints inside the Trash service, moves or skips, and writes the journal as it goes. A crash reads the journal back and does not continue the move. Stop is how a person ends a Run that is spending quota they no longer want to spend.

### Shared-store rule

If consumers are incomplete, the item is kept or queued. It is not proposed as selected. The same bytes are not charged to two projects.

## Modules

A current guess at the boundaries a spike is allowed to cross differently:

- **Skill package, per agent.** The three skills plus a thin writer for the log, the queue, and the index. Installation is opt-in, whole agent by default, per-project opt-out, and has to be verified per harness. Do not inherit Shed's hook contract. If the evals show that only some of an agent's models do a skill well, the skill names that model and asks the agent to run it in a subagent. The mechanism is that agent's own, and it is a guess until the spike sees it work.
- **Local store.** Skills append the per-project log and replace the index. The app reads both and is the only writer of the database, the journal, and checkpoints. Version check at the door.
- **Action boundary.** The only path from "the user approved this exact id" to the Trash service. Skills and Execute both call it. Ask does not.
- **Retrieval.** Given a question and a project id, return memory events and notes with ids and timestamps. No generation.
- **Adapters.** The interface below, one process model. Cursor and Codex are the first two implementations. Claude and Gemini come after those two hold the contract.
- **App UI.** Setup, Home, Ask, Run. SwiftUI is the design doc's candidate. It is not chosen here as a firm rule, and there is no app code in this repository yet.

Throwaway spike code does not graduate into these modules by being left in the tree. A spike is deleted or rewritten once the lesson is recorded.

## Ask Trace

Four ways in, one surface: global Ask (`⌘K` while Trace is focused), a project card, an action card, a Decide-later item. Scope chips show which project and which item. Global Ask searches only projects the user has allowed. It does not upload every project to an agent.

**Memory only.** Retrieve structured facts and quoted notes. The answer cites stable event ids and the time they were verified. A citation that does not resolve is rejected, not linked. Stale sources are labelled. Conflicting notes are shown together; there is no vote. If the log cannot answer, the reply says what is missing. This tier makes no hosted model call. A future on-device generative model would be a separate disclosed tier, not a silent upgrade of "memory."

**Ask agent.** Offered when memory is missing, stale, conflicting, or not enough, and only in M2. Before the first outbound message, show the agent the user picked, the model if one is pinned, the project scope, and which minimized evidence will leave the Mac. There is no token allowance to accept. The user accepts the scope or stays on the partial memory answer. The same two-way session rules as Run apply. This is not a full Run unless the user starts one. The answer separates memory facts, newly observed facts, and inference. Usage is the observed count, or "unavailable." It is never a made-up token total.

Ask can offer "Create action card." It cannot delete, change the never-touch list, install a skill, or run a shell command it just suggested. A follow-up "yes" in the panel is not Execute.

## Lessons from Shed

Shed is archived at `gksoriginals/shed`. This environment could not read it (HTTP 404). PRD v0.2 did, and kept two product lessons plus a safety list. ADR-0001 records the split.

**A full run as the only option burned too many tokens.** Gopi's lesson, not a measured benchmark. Everyday hygiene stays in the session, where the agent already has the context, and the call is a small skill prompt rather than a whole-disk investigation. Home reads disks that were already written. Run is explicit, on demand, and scoped to gaps. It is not given a Trace-side token cap: the agents Gopi uses are mostly on subscription quota, and the screen shows what the Run used. Ask spends agent quota only after memory fails. Cache a tool's official install guidance by tool name and version; do not pay to rediscover it every session.

**Crashes came from having no two-way communication with the agent.** Also Gopi's report; the PRD does not claim a separate root-cause study. The failure mode to design against is a child process started with a one-shot prompt, no channel for a permission question or a follow-up, no stream of life, and no clean way to stop the process group. The UI then either waits forever or shows a result the process never confirmed. Trace's app-agent work is a session that stays open for the turn, speaks in both directions, and can be resumed by id after the process itself is gone. Streaming is necessary and is not, by itself, a crash fix. Deadlines, bounded queues, an explicit terminal event, and cancellation that reaps owned children are the rest of the contract. A heartbeat means "the pipe is alive," not "the task moved."

**Safety that carries over, unchanged in spirit.** Trash only. The never-delete list. Fingerprint re-check at confirm time. Conservative defaults. Recreation cost, current dependents, and source-of-truth, asked of every candidate. Honest numbers: selected bytes, bytes that reached Trash, and measured free-space change are three different figures.

**What does not carry over.** Whole-disk crawl, whole-Mac categories, system junk, Run as the home screen, mandatory Full Disk Access, Shed's test suite, and Shed's numeric release gates. Do not copy Shed's code.

## Agent sessions

The app keeps a Trace conversation per project and task. It does not attach to the user's unrelated coding session. The process may exit when the conversation is idle; the checkpoint is what makes it resumable. Home and memory-only Ask need no process.

On cancel or timeout: send the protocol interrupt, answer or cancel pending permission requests, drain until a terminal event or a short drain deadline, close the pipes, then if the owned helper is still alive signal its process group. Spawn that helper in its own session (`setsid` or the platform equivalent) so the signal hits the helper and the children it started, and not the user's other agents. SIGTERM first, then SIGKILL if the group is still present after the drain deadline. Persist the checkpoint. Do not replay an approval or an Execute. Ask the user before resuming a session that will spend more quota.

Claude's own headless behavior, as documented, already terminates the process tree of a Bash tool still running when the CLI receives SIGTERM, then runs `SessionEnd` hooks and exits. That is not a reason to skip the process-group kill: a stuck CLI may never handle the signal, and a provider cancel does not promise to undo files or stop a detached shell. ACP scope declarations are not an OS sandbox. An adapter that cannot keep app-driven work inside the read-only or consented boundary stays disabled.

Concrete timeout numbers are a guess to be set in the two-way-session spike. The classes are firm: handshake, lost liveness, no useful work, and waiting on the user. These are stuck-session bounds, not a token budget. There is no overall allowance. A long tool call is not, by itself, a crash.

### What the official docs support today

Research date 11 November 2026. Prefer a primary path that can stream, accept a follow-up, answer a permission, interrupt, and resume by id. Fallbacks are for evals, for skills that already run inside the user's own session, or for a disclosed fresh session when resume is absent. They are not a quiet downgrade of Run.

Cursor and Codex are the first two adapters. The sections on Claude and Gemini stay, because the protocols were checked and the later adapters will need them. They are not the spike order and they are not what `evals/run.py` selects on its own.

#### Claude Code and the Claude Agent SDK

Documented two-way path is the **Claude Agent SDK**, not a hand-rolled parse of one-shot CLI output.

- [Streaming input](https://code.claude.com/docs/en/agent-sdk/streaming-vs-single-mode) is the recommended mode: a long-lived process, queued messages, interruption, permission requests, and session state. Single-message `query()` does not interrupt and is not a multi-turn conversation.
- Python [`ClaudeSDKClient`](https://code.claude.com/docs/en/agent-sdk/python) holds the session across exchanges and supports `interrupt()`. After an interrupt, drain `receive_response()` until the interrupted `ResultMessage` before reading the next turn. `query()` can take a stream of messages and still cannot interrupt.
- The [TypeScript SDK](https://code.claude.com/docs/en/agent-sdk/typescript) accepts an async iterable of user messages. `interrupt()` is streaming-input only. When the CLI advertises `interrupt_receipt_v1`, the call resolves with the messages that were still pending. Older CLIs resolve without that receipt.
- [Sessions](https://code.claude.com/docs/en/agent-sdk/sessions) persist the conversation, not the filesystem. Capture `session_id` and pass `resume` to return to that id. `continue` resumes the most recent session in the directory. Fork copies history into a new id. File undo is a separate checkpoint, which matches Trace's rule that session resume is not Trash undo.

CLI, for skills-in-session and for the eval harness, from the [headless guide](https://code.claude.com/docs/en/headless) and the [CLI reference](https://code.claude.com/docs/en/cli-reference):

- `--output-format stream-json` with `--verbose` writes newline-delimited events. `--include-partial-messages` adds token deltas. The last line is a `result` with the text, the cost, and the session id.
- `--input-format stream-json` is a print-mode flag, and `--replay-user-messages` requires both input and output to be `stream-json`. `--resume` takes a session id, a name, or an absolute path to a transcript file. `--continue` resumes the latest conversation. `--max-budget-usd` is a client-side cap and can be overshot; spend from earlier resumed turns does not count toward the new cap. `--max-turns` limits print-mode turns.
- The headless page documents output events (`result`, `stream_event`, `system` / `api_retry`, `permission_denied`) and does not document the stdin message schema. [Issue #24594](https://github.com/anthropics/claude-code/issues/24594) records that gap. Third-party notes mention `control_request` and `control_response`. Those are not the contract. A spike may learn the installed CLI's stdin schema; the app does not build on it until that spike writes down a version and a captured transcript.
- On SIGTERM the CLI terminates Bash tool process trees, emits no further model call, and runs `SessionEnd`. Closing stdin from the SDK cancels a pending permission prompt.

[SDK overview](https://code.claude.com/docs/en/agent-sdk/overview): unless previously approved, Anthropic does not allow third parties to offer claude.ai login or subscription rate limits in their products. Use an approved API key or a supported cloud-provider method. Brand the embedded agent as "Claude Agent" or "Claude," not "Claude Code." An installed Claude Code CLI is a different fact from an SDK entitlement. Setup shows them as separate rows.

**Primary:** Claude Agent SDK streaming client (`ClaudeSDKClient` in Python, or the TypeScript streaming query). Trace owns the process, the permission callback, interrupt-and-drain, and resume by captured session id.

**Fallback:** `claude -p --output-format json` or `stream-json`, with `--resume` when the eval or a script is continuing a print-mode session it started. This is the eval harness path. It is a bad Run transport: each invocation is a new process, and permission replies are not a first-class app channel unless `--permission-prompt-tool` is wired, which is still one-shot per process.

**Not a path:** one-shot CLI parsing as the recovery strategy when the SDK session fails. If the installed SDK cannot hold the contract, the adapter is unavailable.

#### Codex

Two surfaces, with different jobs.

**App-server** is the two-way API, documented on the [app-server page](https://developers.openai.com/codex/app-server/). Default transport is stdio, newline-delimited JSON-RPC (`--listen stdio://`). The wire omits the `"jsonrpc":"2.0"` header. WebSocket listen exists and is described as experimental; a non-loopback listener has allowed unauthenticated connections during rollout. Trace uses stdio only. No listening socket.

Methods the session supervisor needs, as documented: `thread/start`, `thread/resume`, `thread/fork`, `turn/start`, streamed item events, approval replies, `turn/interrupt` (turn ends `interrupted`), and terminal `turn/completed`. Resume by the stored thread id. `excludeTurns: true` plus the pagination methods avoids pulling the entire history in one response. If the saved model provider does not match the current one, resume fails with a provider mismatch; fork starts a new thread from that history. A required MCP server that fails to initialize fails `thread/start` and `thread/resume` rather than continuing without it. Session history is not a filesystem rollback.

The same page's auth section: local and open-source apps may keep using app-server authentication, Sign in with ChatGPT is the recommended migration, and **app-server authentication has never been permitted for commercial or hosted services.** Account methods (`account/read`, `account/login/start`, `account/updated`) report mode. They are not a license to open `auth.json`.

The [MCP-server removal note](https://developers.openai.com/codex/guides/agents-sdk) says `codex mcp-server` and the standalone `codex-mcp-server` binary are gone, and that the app-server command is experimental and not supported for production workloads. Codex as an MCP server is not an integration path. Codex as an MCP *client* remains: the CLI's `codex mcp`, and app-server's `mcpServerStatus/list`, `mcpServer/tool/call`, and `config/mcpServer/reload`.

**Exec** is the scripted path, documented in [non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode). `codex exec` runs one task. `--json` turns stdout into JSON Lines: `thread.started` (includes `thread_id`), `turn.started`, `turn.completed`, `turn.failed`, `item.*`, `error`. `codex exec resume <SESSION_ID>` and `codex exec resume --last` continue a saved session. The default sandbox is read-only; `--sandbox workspace-write` allows edits. `--full-auto` is no longer supported. Progress goes to stderr, the final message to stdout, unless `--json` is set. This is resume across processes, not a live two-way socket, and it has no mid-turn `turn/interrupt` from Trace's UI.

OpenAI's [platform note](https://developers.openai.com/blog/codex-as-a-platform) says the same split: exec for a bounded script, app-server when the agent is part of the product and needs a conversation, streaming, interrupt, and approvals.

**Primary:** `codex app-server` on stdio, pinned to a version the spike actually ran, with `thread/resume` and `turn/interrupt`. This is a first adapter. Treat the vendor's "experimental, not for production" line as a risk Gopi accepts for local dogfood. Commercial and hosted use of this auth is an M2 question, not a block on the spike.

**Fallback:** `codex exec --json` and `codex exec resume <id> --json` for the eval harness and for other scripted one-turn jobs. Interactive `codex resume` belongs to the user's terminal.

**Not a path:** hosting Codex via MCP, an unauthenticated WebSocket, or exec as the Run transport.

#### Cursor

Official [CLI ACP](https://cursor.com/docs/cli/acp): `agent acp`, JSON-RPC 2.0, one JSON object per line, client writes stdin, CLI writes stdout, logs on stderr.

Flow the docs specify: `initialize`, `authenticate` with `methodId: "cursor_login"`, `session/new` or `session/load`, `session/prompt`, handle `session/update`, answer `session/request_permission` (`allow-once`, `allow-always`, `reject-once`), optional `session/cancel`. Modes: `agent`, `plan`, `ask`. Pre-auth can be `agent login`, `--api-key` / `CURSOR_API_KEY`, or `--auth-token` / `CURSOR_AUTH_TOKEN`. Trace should let the user run `agent login` and then spawn the CLI, so the token stays in Cursor's store.

Blocking extension methods `cursor/ask_question` and `cursor/create_plan` wait until the client responds. A client that ignores them leaves the agent stuck. Trace shows them as "Needs your answer" and defaults a scope-widening request to deny. `allow-always` is not used for Trash or for a wider root.

Project and user `.cursor/mcp.json` servers can be used. Team-level MCP from the Cursor dashboard is not supported in ACP, per that page.

The generic ACP spec's `session/resume` and `session/close` are capability-gated. Cursor's page documents `session/load` and `session/cancel`, not `session/resume` or `session/close`. Call only what `initialize` advertised.

**Primary:** `agent acp` as above. This is a first adapter, with Codex. Pin a model with `agent --model <id> acp` when the eval or the skill named one. Cursor's own forum notes that a mid-session model change is not reliable, and that a requested non-fast id can still run as a fast variant. Record the model the session actually reports. Do not treat the launch flag as proof.

**Fallback:** none for the app. `agent resume` is the interactive CLI. If `initialize` lacks `session/load` or the permission channel, the adapter stays unavailable. Skills can still run inside the user's own Cursor session.

#### Gemini CLI

Official [ACP mode](https://geminicli.com/docs/cli/acp-mode/) (page updated 10 April 2026): `gemini --acp`, JSON-RPC over stdio. The page names `initialize`, `authenticate`, `newSession`, `loadSession`, `prompt`, and `cancel`, plus `setSessionMode` and unstable `unstable_setSessionModel`. The wire names are the ACP methods (`session/new`, `session/load`, `session/prompt`, `session/cancel`); the spike confirms the installed binary rather than assuming the prose names are the method strings. The client can register an MCP server at `initialize`. File access can be proxied through the client, which is the boundary Trace wants for reads and writes.

The [ACP session-setup spec](https://agentclientprotocol.com/protocol/session-setup) requires `initialize` first. `session/load` is legal only when `agentCapabilities.loadSession` is true, and it replays history as `session/update`. `session/resume` (no replay) exists only when `sessionCapabilities.resume` is advertised. `session/close` exists only when `sessionCapabilities.close` is advertised, and it cancels like `session/cancel`. Gemini's own page lists load and cancel. It does not list `session/resume` or `session/close`. Do not call them on hope.

A Gemini CLI bug, [issue #28693](https://github.com/google-gemini/gemini-cli/issues/28693) (updated 9 August 2026), reports that `session/load` in the same UTC minute as `session/new` can destroy that session's resumability. The spike checks the installed version and resumes on a session that has already been persisted, instead of assuming the protocol line is enough.

**Primary:** `gemini --acp`, `session/new`, `session/prompt`, `session/cancel`, and `session/load` when the capability is advertised.

**Fallback:** if `loadSession` is absent, start a disclosed fresh session with the minimized memory the user just approved. Do not describe it as a resume. If cancel is absent, the adapter stays off for app-driven work, because Trace cannot promise to stop it.

### Recommendation, per agent

| Agent | When | Primary for Run and agent Ask | Fallback | Leave unavailable when |
| --- | --- | --- | --- | --- |
| Cursor | First | `agent acp`: load, prompt, permission, cancel, and answers to `cursor/ask_question` and `cursor/create_plan`. Pass `--model` at launch when a model is pinned. A later `session/set_config_option` is not proof the runtime model changed. | None for the app. The eval harness speaks ACP, not a one-shot print mode. | Those methods are missing, or a blocking Cursor method is ignored. |
| Codex | First | `codex app-server` on stdio, `thread/resume`, `turn/interrupt`. Local dogfood may use app-server auth. | `codex exec --json` and `codex exec resume`, for a script that is not Run. The eval harness uses app-server. | App-server schema from this install lacks interrupt or resume. Exec is not the substitute for Run. |
| Claude | Later | Agent SDK streaming client, resume by session id | CLI `-p` with `--resume` and JSON or stream-json output, for a script | SDK session cannot interrupt, stream, and resume. Do not drop to fire-and-forget. |
| Gemini | Later | `gemini --acp`, load only if advertised, cancel | Disclosed fresh session when load is missing | Cancel is missing, or the capability handshake fails. |

Skills do not need this table. They run inside the session the user already opened. The adapter is for the app.

## Adapter interface

One interface, four implementations. A current guess at the methods, firm at the behavior.

```text
probe() -> { version, auth: ready | unknown | unsupported | terms_unmet, capabilities }

open(scope, resume_id | null) -> Session

Session.send(message) -> stream of Event
Session.reply(request_id, decision)
Session.interrupt()
Session.cancel()          # interrupt, drain, then kill the owned process group
Session.checkpoint() -> { protocol, session_id, cursor, scope_hash, pending, usage }
```

Events: `status`, `assistant` (factual text, not chain-of-thought), `tool`, `permission`, `question`, `usage`, `completed`, `error`. Unknown events are ignored. A decode error does not tear down the UI.

`capabilities` the supervisor checks before enabling the adapter: stream, multi-turn send, permission reply, interrupt, resume by id, and a terminal event. Missing a required one means unavailable, with the reason on Setup. Optional: MCP servers the user already configured, load-with-replay versus resume-without-replay.

`reply` never sends allow-always for a delete, a credential read, or a wider root. A permission that would expand scope defaults to deny if the user does not answer. Approving a read is not approving Trash.

The supervisor is the only code that spawns the process. Adapters do not start a second hidden process for a follow-up. The first guess is single-flight agent work: a second request waits in view or joins the same read-only conversation.

## Auth and distribution

Gopi's decision for now is local dogfood only. Auth, the way a build is distributed, and the public name wait until M2. Protocol support is not permission to ship further than his Mac. Trace never reads `~/.claude`, `~/.codex/auth.json`, Cursor token files, Gemini credential files, or the keychain to discover a login. "Signed in" is whatever the official status or handshake says. If that is unknown, the UI says unknown.

The options below stay on the page so M2 has them. The choice among them is deferred, except that local dogfood may use the login the user already completed in Cursor and in Codex. Codex app-server auth is fine for that. Its commercial and hosted limits are an M2 question.

Options, which can be combined (skills on one path, the app on another):

1. **Skills only, inside the user's own sessions.** The user signs in with the agent's own CLI. Trace never embeds that login. This matches M0 and needs no extra grant. The first sessions are Cursor and Codex on Gopi's Mac.
2. **Local dogfood app, user already signed in, adapter spawns the CLI.** Cursor: user runs `agent login`, Trace spawns `agent acp`. Gemini: user authenticates in Gemini CLI, Trace spawns `gemini --acp`. Codex: OpenAI allows continued local and open-source use of app-server auth, and recommends moving to Sign in with ChatGPT. Claude: the SDK overview does **not** allow a third-party app to reuse the claude.ai subscription. A local Trace that drives Claude through the Agent SDK needs an approved API key or a supported cloud provider (the docs name this as the Quickstart's API-key methods), even on Gopi's machine, unless Anthropic has approved the subscription path. Detecting an installed `claude` binary is not that approval.
3. **API key or cloud provider, typed or imported by the user into the agent's own login flow.** Claude API key, or Bedrock / Vertex where the SDK supports it. Codex `account/login/start` with an API key, or `CODEX_API_KEY` only in the environment of that process, which the [exec docs](https://learn.chatgpt.com/docs/non-interactive-mode) warn not to leak to untrusted code. The key is entered in the vendor's flow or passed through the environment the user set. Trace does not store a copy in the ledger and does not scrape one from disk.
4. **Commercial or hosted Trace.** Not the current product (Trace is local). If that ever changes: Codex app-server auth is not permitted for commercial or hosted services; Sign in with ChatGPT exists for those use cases and has a partner waitlist. Claude needs Anthropic's approval before any claude.ai login. Cursor and Gemini need their own distribution terms read at that time. Brand rules already forbid presenting the embedded Claude surface as Claude Code.
5. **Distribution of the Mac app.** Separate from auth. (a) Unsigned local build on Gopi's machine. (b) Developer ID signature, notarization, and a direct download, which is the usual path for a developer tool that spawns CLIs and moves files to Trash. (c) Mac App Store, which adds a sandbox that fights arbitrary project roots, Trash outside the container, and child agent processes. (d) No binary: skills only, until (a) or (b) is chosen.

What is locked: M0 is option 1, on Cursor and Codex. Through M2 on Gopi's Mac, the app stays option 5 (a), an unsigned local build, and option 2 for Cursor and Codex. Claude, if a later adapter is turned on, still needs option 3 unless Anthropic has approved subscription reuse. Options 4, 5 (b), and 5 (c), and the public name, are the M2 decision. Do not start them now.

Official marks, if a binary is distributed: use unmodified assets under each vendor's guidelines, or the plain name plus an original glyph. The design doc lists the Claude, OpenAI, Cursor, and Gemini pages. Clearance is part of the distribution decision, not something the adapter invents.

## Privacy and security

Everything Trace stores stays on the Mac. Telemetry is off unless the user turns it on, and the default build does not phone home. The ledger does not contain file bodies, credentials, or raw command output. Access to a coding-agent transcript is explicit and scoped to the project.

Calling a coding agent can send the minimized context of that call to the provider that agent is configured to use. "Local memory" does not mean the agent call is local. The UI says which boundary applies before the call. Outbound context is the question, the cited memory, and the paths in scope, not the whole ledger and not unrelated projects.

Agent events are untrusted data. They do not spawn arbitrary processes, widen scope, or choose Trash targets. Diagnostics shown to the user are redacted and bounded.

## Usage, not caps

Trace does not set a token budget or a time budget. The coding agents in dogfood mostly draw on a subscription quota, and a cap Trace invented would fight that. Onboarding and Settings have no budget fields. Revisit caps only if dogfood shows an uncapped Run is a problem, and record that in a new ADR.

What replaces the caps:

- **Show usage.** After a Run and after an agent-tier Ask, show the input tokens, output tokens, and cost the agent reported for that call. If it reported nothing, show "unavailable." Do not invent a figure, and do not present a client-side flag such as Claude's `--max-budget-usd` as a bill. Cursor's ACP prompt result has been reported without a usage field; the screen says unavailable rather than guessing.
- **Memory first.** Ask reads the project log before any hosted call. The memory tier spends no quota. A cache, keyed by tool name and version, holds official install notes Hygienic setup has already fetched.
- **Small calls.** Skill prompts stay the session's own context plus the relevant memory events, not the full ledger. Run's catch-up is the coverage gap, not a second full history. Run stays on demand.
- **Best value, per agent.** The evals run the same cases on each model that agent offers. The pick is the highest pass rate with no safety miss, then the lowest reported cost. A skill that only some models handle well pins that model and asks the agent to run the skill in a subagent on it. The user still picks the agent for an app-triggered run.

The eval harness records usage per agent×model cell and withholds a best-value pick when cost is missing or only one model was measured. A model's own estimate of its cost is not that number.

## Safety carried from Shed

Restated because every module that touches a file has to be able to say which line it implements.

- **Trash only.** The Trash service moves files. `rm` is not an implementation detail. Container volumes and other irreversible tool operations stay on the report until their own recovery design is accepted.
- **Never-delete list.** Enforced in the skill, in Actions (no checkbox), and again in the Trash service. A card cannot be argued out of the list from Ask.
- **Fingerprint re-check at confirm.** The journal stores the fingerprint of the confirmed selection. The Trash service hashes again immediately before the move. Mismatch skips the item. A symlink that escapes the approved root is rejected. Protected aliases are rejected.
- **Conservative defaults.** Shared, unknown, incomplete, protected, and prior-regret actions start unselected. A verified, nonshared, disposable output may start selected only after dogfood says the policy is right. Until then it starts unselected too. That last sentence is the conservative reading of the PRD's "may," and it is the one to ship first.

The three questions, asked before a proposal becomes selectable: what does recreation cost, what depends on it now, and is it a source of truth? Unknown on any of them means Decide-later or keep.

## Failure and recovery

Three cases the supervisor and the Trash service have to survive. Behavior is firm. The exact copy on screen is the design doc's state matrix.

### A crash mid-run

The process dies without a terminal event. On next open, Trace reads the session checkpoint and the action journal. It shows the last factual milestone, which moves completed, and the usage reported so far. It does not resume Execute, and it does not launch the agent until the user asks. If the user resumes the conversation, the supervisor re-checks the scope hash, reconciles the journal, and continues Reviewing or Ask from the cursor. Completed Trash moves stay completed. There is no automatic rollback.

### A partial Trash

Stop takes effect at an item boundary. Items already journaled as moved stay in the Trash. Items not yet started stay put. The result screen shows selected bytes, moved bytes, and skipped or failed items as separate lines. Undo via Trash offers the journaled subset. Restore never overwrites a path that exists. A missing Trash entry is reported. A restore the user asks for still counts as a regret in the success metric, even when the file comes back.

If the journal write fails before a move, that move does not start. If the disk fills during a move, the service stops at the boundary and the result says the journal may be incomplete. It does not delete more to free space.

### A stuck session

A session is stuck when the handshake never finishes, liveness stops, no useful work arrives before the work deadline, or a permission request sits past the reply deadline. The supervisor interrupts, drains, and kills the owned process group. The checkpoint records the cursor and the unanswered request ids. Those request ids cannot be replied to after reconnect; the user sees them as expired. A new yes is a new request. The UI says whether the helper was reaped. It does not treat a quiet-but-healthy tool call as this case; the spike is what sets the quiet interval.

An adapter that fails the handshake marks itself unavailable and leaves Home readable.

## Housekeeping

### Memory format versioning

`schema_version` on every event, queue item, project, and settings document. Writers produce one version. Readers accept that version and the one before it, and refuse anything else with the file path and the version number, so a newer beta does not silently drop a field. Migrations are explicit events or a one-shot rewrite that keeps the previous file beside the new one until the user dismisses the backup. The eval fixtures pin version 1. Changing the firm fields is an ADR and an eval change together.

Retention is a setting. The preview lists which open decisions and which journal rows would lose their evidence. Those rows stay unless the user accepts the consequence. A deleted note does not delete the artifact. Citations that no longer resolve show as unavailable, and they are not remapped onto a different event.

### Logs the user can see

A bounded, redacted session log the user can open from the run or from Ask: stage changes, tool names, permission decisions, errors, and token counts the agent actually reported. Chain-of-thought stays out. The log is local, exportable by the user, and covered by the same retention preview. It is not a telemetry spool. Crash recovery reads the checkpoint and the journal first; the log is there so a person can see why a session was interrupted.

### Signing and distribution

No binary exists yet. Distribution is local dogfood until M2, so signing is not a task for this milestone. When a build leaves the machine, the proposal to take into that M2 decision is: sign with a Developer ID certificate, notarize, staple, and ship a disk image or a zip. Identifier, version, and the notarization ticket would be part of that release. Automatic update waits until an update feed is a real decision; the app does not add a login item or a background helper to update itself. Entitlements stay as narrow as the chosen roots allow. Hardened runtime has to permit spawning the user-installed agent CLIs, which is a reason to test a signed build before trusting a development signature. The minimum system is macOS 14.

Mac App Store sandboxing is option (c) in [Auth and distribution](#auth-and-distribution), not the default assumption.

## Throwaway spikes

Three spikes come before any of this is treated as buildable. Each one is a short program in a branch or a directory that is deleted when the note lands in an ADR. They are not the app, and they are not wired into the eval harness as production drivers.

1. **Two-way sessions, Cursor and Codex first.** Open a session, stream, send a follow-up, answer a permission, interrupt and drain, kill the process group, resume by id, and show that a resumed session does not repeat a side effect. Cursor is `agent acp`, including answers to `cursor/ask_question` and `cursor/create_plan`, and a check that a requested model id matches the model the session reports. Codex is `codex app-server` on stdio, with `thread/resume` and `turn/interrupt`. Claude's SDK and `gemini --acp` wait until those two are written up. Record versions.
2. **Auth path.** For Cursor and Codex, complete the handshake using only that vendor's own login. Confirm Trace's process never opens a credential file (the spike can be watched with a file-access log the developer runs on their own machine; the product still does not read those files). Write down whether local dogfood reached `ready`. Claude and Gemini are the same check later, not part of this spike. Commercial Codex auth is out of scope until M2.
3. **Project discovery.** From permitted agent workspace history, IDE recents, and Git roots, suggest directories. Compare the list with Gopi's real projects. Count misses, nested duplicates, and anything outside the selected roots. No whole-disk crawl. Confirm a skill can append a per-project log and update the index while the app database stays untouched.

A spike that fails twice stops, per the testing rule, and the report is the result.

## Open questions

The ten product decisions are locked in [ADR-0002](adr/0002-locked-product-decisions.md). These are the ones that record did not close.

1. **Which model is best value, per agent.** The rule is firm. The id is not known until the same cases have been run on the models Cursor and Codex actually offer, with usage reported. Cursor may not return usage on ACP, and a requested model id may not be the one that ran.
2. **Auth, distribution, and the public name at M2.** Local dogfood is the decision until then. The options are written down under Auth and distribution. Codex's commercial auth limit is part of that M2 question.
3. **Shared consumers and tool-native recovery.** The 70% metric is defined. What evidence is enough to call a consumer list complete, and which tool-native actions can be undone, are not.
4. **Judge model for the evals.** The rubric is in [evals.md](evals.md). Which model, of a different family from the skill's model, and when a human labels the dev set, is open. Until kappa is measured, the judge does not gate anything.
5. **Retention, timeout numbers, and checklist mechanics.** How long a journal row is kept, the stuck-session deadlines, and the exact task-list API in Cursor, Codex, and Claude are guesses. Whether any third-party Swift package is worth it is open. The minimum system is not: it is macOS 14.
6. **Two skills appending one log.** The guess is append-only writes and a visible torn line. It is not proven.

Numbers for timeouts, window size, and "preselect disposable output" stay guesses until the spikes and the first eval runs on real sessions. Missing receipts are still not evidence of a missed session, and they are not a reason to re-run cleanup.
