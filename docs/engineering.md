# Trace — engineering direction

**Status:** directional. This is not a locked architecture. **Owner:** Gopi · **Date:** 11 November 2026

Companion to [PRD v0.2](prd.md) and [Design & UX v0.2](design.md). The PRD owns scope and safety. The design owns presentation. This document names the pieces, the data they share, and the decisions that are still open. When a guess below changes, record it in [docs/adr/](adr/).

Checked against official agent docs on 11 November 2026. Those capabilities are documented, not device-tested on Gopi's Mac. `gksoriginals/shed` returned 404 from this environment; Shed lessons below are the ones the PRD kept after reading that archive.

## How to read this

Two kinds of decision sit in this document.

**Firm rules.** Changing one of these is a product decision, an ADR, and usually a safety or eval change. They are listed in the next section and repeated only where a module has to enforce them.

**Current guess, change freely.** Names of modules, file paths, screen composition, timeouts, model choice, and the order of milestones inside a milestone are guesses. They exist so the first spike has something to build. They are not acceptance tests. If a spike shows a better shape, change it and write an ADR. Do not add tests that freeze a guess.

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
10. **Memory before tokens.** Ask answers from project memory first. A hosted model runs only after the user accepts an agent, a scope, and a budget. Ask is read-only: it can propose an action card and cannot execute one.

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
| **Hygienic setup** | Skill, in the coding agent | Before a build, install, environment, container, model, or dataset, look up the current official practice for that tool version. Do the approved setup. Avoid a needless copy. Record what changed, why, where, how to recreate or reverse it, and which project depends on it. | A blanket "containers are always smaller." |
| **Session-end cleanup** | Skill, in the coding agent | At the end of the session, propose removal of short-lived files the session created, inside the scope the user already allowed. Ask before anything else. | A delete that happens because the session ended. |
| **Memory writer** | Skill, in the coding agent | Append compact events: artifacts, setup changes, cleanup outcomes, coverage receipts, and a few evidence-backed lessons. | A second summary universe, or a dump of every command. |
| **Decide-later** | Any skill writes it; Home shows it | A durable local queue item when a storage decision is doubtful. | A notification counter, or a timer that deletes when it expires. |
| **Setup** | App | Agents and whether the CLI is installed, the version, and sign-in as verified or unknown. Opt-in skills. Whole-agent or selected-projects install. Project roots and categories. Guardrails, cost, lifecycle. | A whole-disk permission wizard, or setup again before every run. |
| **Home** | App | Decide-later at the top. Then one insight card per project: what Trace did, setup changes that matter, storage outcomes, coverage. Read local records only. | A Run screen, a file inventory, or a transcript feed. |
| **Ask Trace** | App | One question surface. Memory first. The coding agent only when memory is not enough, and only after a fresh budget. | A general chatbot, or a way to execute cleanup from chat. |
| **Run** | App, on demand | Three stages: **Reviewing**, then **Actions** (cards), then **Execute**. Uses memory, then a targeted catch-up where coverage has a gap. Shows the agent, the model, and the token and time allowance before it starts. Costs more tokens than a skill. | The way everyday cleanup happens, or a refresh on every app open. |

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
| Settings | Opt-in skills, install scope, never-touch list, budgets, retention, notifications. |
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

Four stores are the product's memory. Receipts, the journal, and checkpoints sit beside them. All of them are local files. The directory is a guess: `~/Library/Application Support/Trace/` for the app, and a project-local `.trace/` so skills can write while the app is absent. The app imports the project-local log; it does not invent a second history. Concurrent writes are an open question; the first guess is one writer per file, with an atomic replace, and a conflict surfaced to the user rather than last-write-wins.

Schema version lives on every record. A reader accepts the current version and the previous one. An unknown version is refused and shown, not guessed.

### Memory log

Version 1. One JSON object per line. Firm fields:

| Field | Required content |
| --- | --- |
| `schema_version` | `1` |
| `event_id` | Stable id. Never reused. |
| `event_type` | `artifact`, `setup_change`, `cleanup_outcome`, `coverage_receipt`, `correction`, or `lesson` |
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

A project record holds display name, selected roots, which categories are in scope (caches, builds and environments, worktrees, containers, models, project data — all on means inspect, not delete), and notes for shared stores: known consumers, evidence date, recreation cost, and an explicit unknown. Shared bytes are counted once.

### Settings

One local document. It holds opted-in skills, install scope per agent (whole agent or selected projects), the never-touch list, category scope, the Run budget and the Ask budget (tokens and time, separately), memory-retention preference, menu-bar and Decide-later notification opt-in, and the optional review schedule, which is off. Appearance and the Freed sound live here too.

A signed-in CLI is recorded as a status the adapter reports (`ready`, `unknown`, `unsupported`, `terms_unmet`). The status is not a copy of a token.

### Supporting records

**Coverage receipt.** Project, agent, skill name, skill version, start, end, state (`completed`, `partial`, `failed`), and the session or event range covered. An old timestamp by itself is not a gap. A known session with no completed receipt is a gap. Unknown is labelled unknown.

**Action journal.** Selection id, each path or tool id, fingerprint at confirm time, fingerprint immediately before the move, Trash destination, outcome (`moved`, `skipped`, `failed`), and why. Execute is disabled when the journal cannot be written. Undo restores only journaled Trash items, and never overwrites a destination that now exists.

**Session checkpoint.** Project, agent, protocol version, session or thread or turn ids, last handled event cursor, scope and policy hash, pending request ids, and which budget remains. Resume uses this. Resume does not replay Execute or a previous approval.

## Main logic

### During a coding session

Hygienic setup runs before the agent creates storage. It records the location it actually used. Session-end cleanup runs when the session is finishing. It writes proposals, queue items, and, only for an exact prior yes, a Trash move through the action boundary. The memory writer appends events for all of that. The app can be closed the whole time.

### Home

Read the queue, the log, receipts, and the journal. Group insight cards by project. Badge each event as skill, app run, or the user. Keep and defer on a queue item are local writes with no model call. A removal still has to become an action card and pass Execute.

### Ask Trace

Described in [Ask Trace](#ask-trace). Memory retrieval is a local read. Agent escalation opens the session supervisor.

### Run

The user picks a project and sees the allowance. Reviewing streams factual milestones into a checkpointed session. Actions are built from memory plus what Reviewing just verified. Execute freezes the selection, re-checks fingerprints inside the Trash service, moves or skips, and writes the journal as it goes. A crash reads the journal back and does not continue the move.

### Shared-store rule

If consumers are incomplete, the item is kept or queued. It is not proposed as selected. The same bytes are not charged to two projects.

## Modules

A current guess at the boundaries a spike is allowed to cross differently:

- **Skill package, per agent.** The three skills plus a thin writer for the log and the queue. Installation is opt-in, whole-agent or per-project, and has to be verified per harness. Do not inherit Shed's hook contract.
- **Local store.** Readers and writers for the four stores, receipts, journal, and checkpoints. Version check at the door.
- **Action boundary.** The only path from "user said yes to this exact id" to the Trash service. Skills and Execute both call it. Ask does not.
- **Retrieval.** Given a question and a project id, return memory events and notes with ids and timestamps. No generation.
- **Adapters.** The interface below, one process model, four implementations.
- **App UI.** Setup, Home, Ask, Run. SwiftUI is the design doc's candidate. It is not chosen here as a firm rule, and there is no app code in this repository yet.

Throwaway spike code does not graduate into these modules by being left in the tree. A spike is deleted or rewritten once the lesson is recorded.

## Ask Trace

Four ways in, one surface: global Ask (`⌘K` while Trace is focused), a project card, an action card, a Decide-later item. Scope chips show which project and which item. Global Ask searches only projects the user has allowed. It does not upload every project to an agent.

**Memory only.** Retrieve structured facts and quoted notes. The answer cites stable event ids and the time they were verified. A citation that does not resolve is rejected, not linked. Stale sources are labelled. Conflicting notes are shown together; there is no vote. If the log cannot answer, the reply says what is missing. This tier makes no hosted model call. A future on-device generative model would be a separate disclosed tier, not a silent upgrade of "memory."

**Ask agent.** Offered when memory is missing, stale, conflicting, or not enough, and only in M2. Before the first outbound message, show the agent, the model, the project scope, which minimized evidence will leave the Mac, and the extra token and time allowance. The user accepts or stays on the partial memory answer. The same two-way session rules as Run apply. This is not a full Run unless the user starts one. The answer separates memory facts, newly observed facts, and inference. Usage is the observed count, or "unavailable." It is never a made-up token total.

Ask can offer "Create action card." It cannot delete, change the never-touch list, install a skill, or run a shell command it just suggested. A follow-up "yes" in the panel is not Execute.

## Lessons from Shed

Shed is archived at `gksoriginals/shed`. This environment could not read it (HTTP 404). PRD v0.2 did, and kept two product lessons plus a safety list. ADR-0001 records the split.

**A full run as the only option burned too many tokens.** Gopi's lesson, not a measured benchmark. Everyday hygiene stays in the session, where the agent already has the context, and the call is a small skill prompt rather than a whole-disk investigation. Home reads disks that were already written. Run is explicit, budgeted, and scoped to gaps. Ask spends agent tokens only after memory fails. Cache a tool's official install guidance by tool name and version; do not pay to rediscover it every session.

**Crashes came from having no two-way communication with the agent.** Also Gopi's report; the PRD does not claim a separate root-cause study. The failure mode to design against is a child process started with a one-shot prompt, no channel for a permission question or a follow-up, no stream of life, and no clean way to stop the process group. The UI then either waits forever or shows a result the process never confirmed. Trace's app-agent work is a session that stays open for the turn, speaks in both directions, and can be resumed by id after the process itself is gone. Streaming is necessary and is not, by itself, a crash fix. Deadlines, bounded queues, an explicit terminal event, and cancellation that reaps owned children are the rest of the contract. A heartbeat means "the pipe is alive," not "the task moved."

**Safety that carries over, unchanged in spirit.** Trash only. The never-delete list. Fingerprint re-check at confirm time. Conservative defaults. Recreation cost, current dependents, and source-of-truth, asked of every candidate. Honest numbers: selected bytes, bytes that reached Trash, and measured free-space change are three different figures.

**What does not carry over.** Whole-disk crawl, whole-Mac categories, system junk, Run as the home screen, mandatory Full Disk Access, Shed's test suite, and Shed's numeric release gates. Do not copy Shed's code.

## Agent sessions

The app keeps a Trace conversation per project and task. It does not attach to the user's unrelated coding session. The process may exit when the conversation is idle; the checkpoint is what makes it resumable. Home and memory-only Ask need no process.

On cancel or timeout: send the protocol interrupt, answer or cancel pending permission requests, drain until a terminal event or a short drain deadline, close the pipes, then if the owned helper is still alive signal its process group. Spawn that helper in its own session (`setsid` or the platform equivalent) so the signal hits the helper and the children it started, and not the user's other agents. SIGTERM first, then SIGKILL if the group is still present after the drain deadline. Persist the checkpoint. Do not replay an approval or an Execute. Ask the user before spending more tokens.

Claude's own headless behavior, as documented, already terminates the process tree of a Bash tool still running when the CLI receives SIGTERM, then runs `SessionEnd` hooks and exits. That is not a reason to skip the process-group kill: a stuck CLI may never handle the signal, and a provider cancel does not promise to undo files or stop a detached shell. ACP scope declarations are not an OS sandbox. An adapter that cannot keep app-driven work inside the read-only or consented boundary stays disabled.

Concrete timeout numbers are a guess to be set in the two-way-session spike. The classes are firm: handshake, lost liveness, no useful work, overall allowance, and waiting on the user. A long tool call is not, by itself, a crash.

### What the official docs support today

Research date 11 November 2026. Prefer a primary path that can stream, accept a follow-up, answer a permission, interrupt, and resume by id. Fallbacks are for evals, for skills that already run inside the user's own session, or for a disclosed fresh session when resume is absent. They are not a quiet downgrade of Run.

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

**Primary:** `codex app-server` on stdio, pinned to a version the spike actually ran, with `thread/resume` and `turn/interrupt`. Treat the vendor's "experimental, not for production" line as a risk Gopi accepts for local dogfood, not as a claim Trace can ship commercially on this auth.

**Fallback:** `codex exec --json` and `codex exec resume <id> --json` for the eval harness and for other scripted one-turn jobs. Interactive `codex resume` belongs to the user's terminal.

**Not a path:** hosting Codex via MCP, an unauthenticated WebSocket, or exec as the Run transport.

#### Cursor

Official [CLI ACP](https://cursor.com/docs/cli/acp): `agent acp`, JSON-RPC 2.0, one JSON object per line, client writes stdin, CLI writes stdout, logs on stderr.

Flow the docs specify: `initialize`, `authenticate` with `methodId: "cursor_login"`, `session/new` or `session/load`, `session/prompt`, handle `session/update`, answer `session/request_permission` (`allow-once`, `allow-always`, `reject-once`), optional `session/cancel`. Modes: `agent`, `plan`, `ask`. Pre-auth can be `agent login`, `--api-key` / `CURSOR_API_KEY`, or `--auth-token` / `CURSOR_AUTH_TOKEN`. Trace should let the user run `agent login` and then spawn the CLI, so the token stays in Cursor's store.

Blocking extension methods `cursor/ask_question` and `cursor/create_plan` wait until the client responds. A client that ignores them leaves the agent stuck. Trace shows them as "Needs your answer" and defaults a scope-widening request to deny. `allow-always` is not used for Trash or for a wider root.

Project and user `.cursor/mcp.json` servers can be used. Team-level MCP from the Cursor dashboard is not supported in ACP, per that page.

The generic ACP spec's `session/resume` and `session/close` are capability-gated. Cursor's page documents `session/load` and `session/cancel`, not `session/resume` or `session/close`. Call only what `initialize` advertised.

**Primary:** `agent acp` as above.

**Fallback:** none for the app. `agent resume` is the interactive CLI. If `initialize` lacks `session/load` or the permission channel, the adapter stays unavailable. Skills can still run inside the user's own Cursor session.

#### Gemini CLI

Official [ACP mode](https://geminicli.com/docs/cli/acp-mode/) (page updated 10 April 2026): `gemini --acp`, JSON-RPC over stdio. The page names `initialize`, `authenticate`, `newSession`, `loadSession`, `prompt`, and `cancel`, plus `setSessionMode` and unstable `unstable_setSessionModel`. The wire names are the ACP methods (`session/new`, `session/load`, `session/prompt`, `session/cancel`); the spike confirms the installed binary rather than assuming the prose names are the method strings. The client can register an MCP server at `initialize`. File access can be proxied through the client, which is the boundary Trace wants for reads and writes.

The [ACP session-setup spec](https://agentclientprotocol.com/protocol/session-setup) requires `initialize` first. `session/load` is legal only when `agentCapabilities.loadSession` is true, and it replays history as `session/update`. `session/resume` (no replay) exists only when `sessionCapabilities.resume` is advertised. `session/close` exists only when `sessionCapabilities.close` is advertised, and it cancels like `session/cancel`. Gemini's own page lists load and cancel. It does not list `session/resume` or `session/close`. Do not call them on hope.

A Gemini CLI bug, [issue #28693](https://github.com/google-gemini/gemini-cli/issues/28693) (updated 9 August 2026), reports that `session/load` in the same UTC minute as `session/new` can destroy that session's resumability. The spike checks the installed version and resumes on a session that has already been persisted, instead of assuming the protocol line is enough.

**Primary:** `gemini --acp`, `session/new`, `session/prompt`, `session/cancel`, and `session/load` when the capability is advertised.

**Fallback:** if `loadSession` is absent, start a disclosed fresh session with the minimized memory the user just approved. Do not describe it as a resume. If cancel is absent, the adapter stays off for app-driven work, because Trace cannot promise to stop it.

### Recommendation, per agent

| Agent | Primary for Run and agent Ask | Fallback | Leave unavailable when |
| --- | --- | --- | --- |
| Claude | Agent SDK streaming client, resume by session id | CLI `-p` with `--resume` and JSON or stream-json output, for evals and scripts | SDK session cannot interrupt, stream, and resume. Do not drop to fire-and-forget. |
| Codex | `codex app-server` on stdio, `thread/resume`, `turn/interrupt` | `codex exec --json` and `codex exec resume`, for evals and scripts | App-server schema from this install lacks interrupt or resume. Exec is not the substitute for Run. |
| Cursor | `agent acp`: load, prompt, permission, cancel, and answers to `cursor/ask_question` and `cursor/create_plan` | None for the app | Those methods are missing, or a blocking Cursor method is ignored. |
| Gemini | `gemini --acp`, load only if advertised, cancel | Disclosed fresh session when load is missing | Cancel is missing, or the capability handshake fails. |

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
Session.checkpoint() -> { protocol, session_id, cursor, scope_hash, pending, budget }
```

Events: `status`, `assistant` (factual text, not chain-of-thought), `tool`, `permission`, `question`, `usage`, `completed`, `error`. Unknown events are ignored. A decode error does not tear down the UI.

`capabilities` the supervisor checks before enabling the adapter: stream, multi-turn send, permission reply, interrupt, resume by id, and a terminal event. Missing a required one means unavailable, with the reason on Setup. Optional: MCP servers the user already configured, load-with-replay versus resume-without-replay.

`reply` never sends allow-always for a delete, a credential read, or a wider root. A permission that would expand scope defaults to deny if the user does not answer. Approving a read is not approving Trash.

The supervisor is the only code that spawns the process. Adapters do not start a second hidden process for a follow-up. The first guess is single-flight agent work: a second request waits in view or joins the same read-only conversation.

## Auth and distribution

This is a product decision for Gopi. Protocol support is not permission to ship. Trace never reads `~/.claude`, `~/.codex/auth.json`, Cursor token files, Gemini credential files, or the keychain to discover a login. "Signed in" is whatever the official status or handshake says. If that is unknown, the UI says unknown.

Options, which can be combined (skills on one path, the app on another):

1. **Skills only, inside the user's own sessions.** The user signs in with the agent's own CLI. Trace never embeds that login. This matches M0 and needs no extra grant. It is the path that works today for Claude Code and Codex on Gopi's Mac.
2. **Local dogfood app, user already signed in, adapter spawns the CLI.** Cursor: user runs `agent login`, Trace spawns `agent acp`. Gemini: user authenticates in Gemini CLI, Trace spawns `gemini --acp`. Codex: OpenAI allows continued local and open-source use of app-server auth, and recommends moving to Sign in with ChatGPT. Claude: the SDK overview does **not** allow a third-party app to reuse the claude.ai subscription. A local Trace that drives Claude through the Agent SDK needs an approved API key or a supported cloud provider (the docs name this as the Quickstart's API-key methods), even on Gopi's machine, unless Anthropic has approved the subscription path. Detecting an installed `claude` binary is not that approval.
3. **API key or cloud provider, typed or imported by the user into the agent's own login flow.** Claude API key, or Bedrock / Vertex where the SDK supports it. Codex `account/login/start` with an API key, or `CODEX_API_KEY` only in the environment of that process, which the [exec docs](https://learn.chatgpt.com/docs/non-interactive-mode) warn not to leak to untrusted code. The key is entered in the vendor's flow or passed through the environment the user set. Trace does not store a copy in the ledger and does not scrape one from disk.
4. **Commercial or hosted Trace.** Not the current product (Trace is local). If that ever changes: Codex app-server auth is not permitted for commercial or hosted services; Sign in with ChatGPT exists for those use cases and has a partner waitlist. Claude needs Anthropic's approval before any claude.ai login. Cursor and Gemini need their own distribution terms read at that time. Brand rules already forbid presenting the embedded Claude surface as Claude Code.
5. **Distribution of the Mac app.** Separate from auth. (a) Unsigned local build on Gopi's machine. (b) Developer ID signature, notarization, and a direct download, which is the usual path for a developer tool that spawns CLIs and moves files to Trash. (c) Mac App Store, which adds a sandbox that fights arbitrary project roots, Trash outside the container, and child agent processes. (d) No binary: skills only, until (a) or (b) is chosen.

Recommendation, as an engineering input and not the decision: ship M0 as option 1. For M1 and M2 on Gopi's Mac, use option 2 for Codex, Cursor, and Gemini, and option 3 for Claude unless Anthropic approves subscription reuse. Keep option 5 at (a) until someone other than Gopi runs it, then (b). Revisit (c) and (4) only if the product stops being a local app.

Official marks, if a binary is distributed: use unmodified assets under each vendor's guidelines, or the plain name plus an original glyph. The design doc lists the Claude, OpenAI, Cursor, and Gemini pages. Clearance is part of the distribution decision, not something the adapter invents.

## Privacy and security

Everything Trace stores stays on the Mac. Telemetry is off unless the user turns it on, and the default build does not phone home. The ledger does not contain file bodies, credentials, or raw command output. Access to a coding-agent transcript is explicit and scoped to the project.

Calling a coding agent can send the minimized context of that call to the provider that agent is configured to use. "Local memory" does not mean the agent call is local. The UI says which boundary applies before the call. Outbound context is the question, the cited memory, and the paths in scope, not the whole ledger and not unrelated projects.

Agent events are untrusted data. They do not spawn arbitrary processes, widen scope, or choose Trash targets. Diagnostics shown to the user are redacted and bounded.

## Cost controls

Two budgets, both shown before any hosted call, both a firm requirement with numbers that dogfood will set:

- **Per Run.** Token allowance and time allowance for Reviewing through Execute. Exhaustion stops at the next safe boundary, keeps the partial checkpoint, and does not start Execute by itself.
- **Per Ask.** The memory tier spends none of it. The agent tier has its own allowance, accepted per escalation, not borrowed silently from the Run budget.

Memory-only answers are tried first, every time. A cache, keyed by tool name and version, holds official install notes Hygienic setup has already fetched. Skill prompts stay small: the session's own context plus the relevant memory events, not the full ledger. Run's catch-up is bounded to the coverage gap, not a second full history.

Usage on screen is the count the agent reported, or "unavailable." A client-side cap, such as Claude's `--max-budget-usd`, is a best-effort stop and can be passed by the last turn. The UI says that. It does not present the cap as a bill.

The eval harness reports tokens when the CLI reports them, and otherwise "unavailable," for the same reason. Cost per successful case is the comparison to use once live runs exist. A model's own estimate of its cost is not that number.

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

The process dies without a terminal event. On next open, Trace reads the session checkpoint and the action journal. It shows the last factual milestone and which moves completed. It does not resume Execute, and it does not launch the agent until the user asks. If the user resumes the conversation, the supervisor re-checks the scope hash and the remaining budget, reconciles the journal, and continues Reviewing or Ask from the cursor. Completed Trash moves stay completed. There is no automatic rollback.

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

No binary exists yet. When one does, the engineering default to propose is: sign with a Developer ID certificate, notarize, staple, and ship a disk image or a zip. Identifier, version, and the notarization ticket are part of the release, not a later polish pass. Automatic update waits until an update feed is a real decision; the app does not add a login item or a background helper to update itself. Entitlements stay as narrow as the chosen roots allow. Hardened runtime has to permit spawning the user-installed agent CLIs, which is a reason to test a signed build in the auth spike rather than assume a development signature behaves the same.

Mac App Store sandboxing is option (c) in [Auth and distribution](#auth-and-distribution), not the default assumption.

## Throwaway spikes

Three spikes come before any of this is treated as buildable. Each one is a short program in a branch or a directory that is deleted when the note lands in an ADR. They are not the app, and they are not wired into the eval harness as production drivers.

1. **Two-way sessions, Claude and Codex first.** Open a session, stream, send a follow-up, answer a permission, interrupt and drain, kill the process group, resume by id, and show that a resumed session does not repeat a side effect. Then a thinner pass on `agent acp` and `gemini --acp` for the capability bits this document is unsure about: Cursor's blocking extension methods, Gemini's wire method names, and whether `session/load` on the installed Gemini survives a restart. Record versions.
2. **Auth path.** For each agent, complete handshake using only the vendor's own login. Confirm Trace's process never opens a credential file (the spike can be watched with a file-access log the developer runs on their own machine; the product still does not read those files). Write down which of options 1–3 actually reached `ready` for Claude, Codex, Cursor, and Gemini.
3. **Project discovery.** From permitted agent workspace history, IDE recents, and Git roots, suggest directories. Compare the list with Gopi's real projects. Count misses, nested duplicates, and anything outside the selected roots. No whole-disk crawl.

A spike that fails twice stops, per the testing rule, and the report is the result.

## Open questions and product decisions

Engineering can frame these. Gopi decides them. The first four are the PRD's open questions, restated with the choice this document thinks is in front of him.

1. **What may a skill remove without asking again?** Exact paths the user already named, versus nothing until Home. "Automatic" is not a candidate. This blocks the session-end skill's consent line.
2. **Whole-agent install or per-project install, per harness?** Which of Claude Code, Codex, Cursor, and Gemini actually support each scope without loading the skill twice. A project-only install is a valid setup.
3. **Default budgets, and what happens at zero.** The token and time numbers for Run and for Ask, and whether exhaustion pauses for an extension or ends the session. Missing receipts are not evidence of a missed session, so the budget is not a reason to re-run cleanup "to be sure."
4. **The 70% denominator.** Which bytes count as agent-created, the observation window, and how persistent storage, shared caches, and bytes sitting in Trash count. Shared consumers: what evidence is enough to say the list is complete, and which tool-native actions can be undone.
5. **Where the files live, and how two writers coexist.** App support directory, project-local `.trace/`, or both with import. What retention keeps journal rows without keeping every transcript.
6. **Background review.** Off by default is firm. Whether an opted-in review runs only while Trace is open or also after quit depends on a macOS mechanism the spike has not validated. No scheduled Execute.
7. **Auth and distribution.** Options in [Auth and distribution](#auth-and-distribution). The engineering input is skills-only first, API-key or cloud auth for embedded Claude, CLI-owned login for Codex, Cursor, and Gemini, Developer ID when a binary leaves the machine. The decision is still Gopi's, including the public name, which the PRD already flags as crowded.
8. **First app adapter after the spikes.** Claude SDK and Codex app-server are the two Gopi uses. The spike results pick the first one the app speaks. Cursor and Gemini wait on their capability notes.
9. **Judge model for the evals.** The rubric is in [evals.md](evals.md). Which model, of a different family from the skill's model, and when a human labels the dev set, is open. Until kappa is measured, the judge does not gate anything.
10. **Minimum macOS, and whether any third-party Swift package is worth it.** The design doc's candidate is macOS 13 for `MenuBarExtra`. Unvalidated. No third-party UI dependency until a gap shows up.

Numbers for timeouts, window size, and "preselect disposable output" stay guesses until the spikes and the first eval runs on real sessions.
