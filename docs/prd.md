# Trace — PRD v0.2

**Status:** skills/app split, Ask Trace and two-way sessions revision; supersedes v0.1. Product decisions in §13 are locked by [ADR-0002](adr/0002-locked-product-decisions.md). How the skills ship is [ADR-0004](adr/0004-skills-not-a-plugin.md). · **Owner:** Gopi · **Date:** 11 November 2026 (IST)

Trace is the chosen working name. A closely adjacent AI-agent analytics app and another macOS app already use it; qualify or revisit the public name before launch. Do not assume an unqualified `trace`, `trace-cli` or `tracecli` command is available. This document defines a new product, not another phase of Shed.

## 1. One-line pitch

**Trace is storage hygiene inside your coding agents, with an app that shows what happened, resolves doubtful decisions and runs a deeper pass when needed.**

## 2. Why

**Problem.** Project work accumulates builds, environments, dependencies, worktrees, containers, models and data. A cleaner inspecting them afterward cannot reliably know why they exist, what still depends on them or what it costs to recreate them. Age and size are not proof of disposability.

**Why now — product hypothesis, not user research.** Coding agents both create this storage and know the task that created it. Capture that context during work rather than reconstructing it from filenames later.

**Why skills beat cleaners.** Hygienic setup prevents unnecessary copies and unmanaged installations. Session-end cleanup resolves temporary leftovers while context is fresh. Memory preserves the reason for everything that must remain. The app is the review and recovery surface, not the primary cleanup engine.

### Lessons from Shed that shape Trace

- **A full run as the only option burned too many tokens.** This is Gopi's product lesson, not a measured cost-reduction claim. Trace moves everyday work into in-session skills; Home reads local outcomes; deep Run is an explicit fallback/catch-up. The user picks the coding agent. Trace does not set a token or time cap. It shows the usage that Run or Ask reported. Ask Trace tries project memory before spending agent quota.
- **The app needs two-way communication with its coding agent.** Gopi reported crashes associated with the old lack of two-way communication; this document does not claim a separately diagnosed crash root cause. Trace must maintain a **persistent, resumable, bidirectional session** for app-agent work: streaming events, follow-up messages, permission/questions, explicit terminal states, deadlines, clean cancellation and recovery. No one-shot fire-and-forget process call that leaves the UI guessing or the child process orphaned. The protocol is a reliability requirement, not a claim that streaming alone prevents crashes.

## 3. Who

Start with Gopi using Cursor and Codex on his Mac, across coding projects and data-intensive work surfaces. Claude and Gemini are later adapters. Expand to other agent-heavy developers only after dogfood establishes usefulness and trust. No interviews, market-size claims or measured user outcomes are assumed. The minimum system is macOS 14.

## 4. Product contract — skills do the everyday work; the app supervises

**Locked split:** skills are not just suggestions for the app to execute later. They work inside coding agents during project work. The app configures that behavior, shows its outcomes and handles uncertainty; a separate, more token-intensive Run catches up or investigates deeply. Opening Home must not start a model call or scan.

### The three skills and their shared Decide-later contract

1. **Hygienic setup — prevent avoidable storage.** The skill runs while the coding agent works. Before a build, install, environment, container, model or data setup, it nudges the user and asks. It looks up the healthiest, most efficient current practice for that tool version and adds the steps to the agent's own task checklist. It performs the setup the user approved, avoids needless copies, and records the decision plus the change: what changed, why, where, how to recreate/reverse it and which project depends on it. Next time it follows that recorded decision. Containers or shared stores are not automatically the smallest/best option.
2. **Session-end cleanup — leave the work surface tidy.** Use the session's context to clean disposable leftovers within the user's explicitly approved scope/host permissions, rather than requiring an app run. Before a removal, nudge the user and ask. The skill may remove something without asking again only when the user approved that exact item before. Uncertainty, criticality or shared-consumer ambiguity goes to **Decide later**, never a guess. Reuse the path/current-use/source protections and Trash/journal semantics through a small shared action boundary; skills must not need the app UI to be open.
3. **Memory writer — preserve provenance and useful lessons.** Write compact artifact/lifecycle events, important local setup changes, actual cleanup outcomes, skill-run coverage receipts and salient evidence-backed lessons. Separate observed/verified/inferred facts; preserve corrections and successful practices, not every file/command. The app consumes the same local evidence, not an independently maintained summary universe.

**Decide later is a durable local queue**, produced by any skill when a storage decision is doubtful. Each item has a stable ID, project/agent/session, affected artifact or action, why it is doubtful, known bytes/completeness, evidence references, what would resolve the doubt, first/last observed time and status. Deduplicate repeated reports; a new observation updates evidence, not notification count. Proposed states: open, planned, deferred, kept, resolved or stale. Nothing is deleted because a queue item is old. A resolved item's outcome remains in history.

Skills work without the app. They are three portable Agent Skills — hygienic setup, session-end cleanup, and the memory writer — that share one set of schemas, scripts, and safety rules. Install copies them into that host's own skills folder, for example with `npx skills add`, and adds one line to the project's `AGENTS.md`, Cursor rule, or `CLAUDE.md` saying when to use them. Models often skip a skill that is installed but not named. A project that opted out does not get that line.

Hooks are optional, opt-in, and per host. A hook is a stop or session-end hook, and it only calls the same helper or queues work. Session-end budgets are about 1–3 seconds, so the hook is not where the work happens. Memory is written during the work or at the end of a turn. There is no MCP server. Versioned files with atomic writes are the store. A plugin comes later, only as a thin wrapper for marketplace install or team policy. [ADR-0004](adr/0004-skills-not-a-plugin.md).

### App information architecture

| Surface | Its job | It must not become |
| --- | --- | --- |
| **Setup** | Agents and CLI availability/sign-in status; opted-in skills; project directories; category scope; whole-agent install with a per-project opt-out; safety and lifecycle preferences. No budget settings. | A mandatory whole-disk permission wizard, a budget form, or repeated setup before every run. |
| **Home — default** | Decide-later queue at the top, followed by insights per project: what Trace did, important local setup changes, storage outcomes and coverage/freshness. Read local records; no provider call just to render. | A Run screen, a giant file inventory or a feed of raw agent transcripts. |
| **Ask Trace — contextual** | One question surface reached globally, per project, per action or per Decide-later item; memory-first cited answers and explicit agent-tier escalation. | A general chatbot, hidden full Run or chat-based execution bypass. |
| **Run — explicit, deeper and costlier** | A fully agentic, on-demand pass through **Reviewing → Actions → Execute**, using existing memories and targeted catch-up where skills were absent or coverage has gaps. Started **per project** or across **all permitted Trace projects** (selected roots / index) — never whole-disk. | A prerequisite for routine skill work, an always-on whole-disk crawler or a token-burning refresh on each app open. |

### Ask Trace — memory first, agent only when necessary

**Entry points:** one global **Ask Trace** bar (`⌘K` while Trace is focused), project Ask, an action card's Ask and a Decide-later item's Ask. They open the **same** surface with explicit scope chips, not four separate chat systems. Global Ask searches permitted local project indexes first; agent escalation is project-scoped and never silently uploads every project's memory.

The first tier is **Memory only**: local retrieval over the **full memory corpus for the Ask scope** (one project or all permitted projects). Prefer structured fields and explicit path identity; do not bag-of-words keyword-search the log. Concise evidence-backed answers or quoted matches, citations to stable memory/evidence IDs and last-verified time. No hidden hosted model call. If a generative local model is later added, disclose its actual execution/cost separately; do not call an uncited model guess a memory fact.

If memory is missing, stale, conflicting or insufficient, say exactly what is unknown and offer **Ask agent** with the selected project, the coding agent the user picked, and the scope, before the first outbound message. There is no token allowance to accept. M2 escalates through the same two-way session contract as Run, preserving follow-ups, permission requests, streaming and Stop/resume. It does not start a full deep Run unless the user chooses that separate broader scope. Show the tier in both question and answer, and show observed usage or “unavailable”. Never fabricate token counts or billing precision.

Answers cite memory entries and inspected evidence; stale sources are labelled, unknown citation IDs are rejected and unsupported claims remain qualified. Ask is read-only: recommendations may propose an action card, but no answer, `⌘K` command or yes/no follow-up bypasses Actions selection, final consent and native safety checks.

### Required two-way agent session design

Use a dedicated, scope-bound Trace conversation, not a hijack of an unrelated live coding session. Persist project/agent/protocol version, session/thread/turn IDs, last handled event/cursor, scope/policy hash and pending request IDs. Keep the active transport open for interaction; a durable session can survive process teardown/reconnect without keeping an always-on model process alive. Home/memory-only Ask require neither a live agent process nor a model call.

The adapter contract includes capability/auth handshake; multi-turn send/stream; explicit input/permission replies; completion/error states; handshake, work, idle/liveness and approval-wait deadlines; bounded event/pipe queues; cancellation acknowledgement plus terminal drain; and explicit resume by ID. A heartbeat is liveness, not work progress. On timeout/cancel, interrupt first, drain/close safely, then terminate only owned helpers if needed; persist the resumable checkpoint. Never replay Execute or an approval after reconnect. Reconcile the native action journal before suggesting any continuation, recheck policy and current identity, and ask the user before resuming paid work. Fail visibly if the installed version cannot satisfy this contract; do not fall back to fire-and-forget parsing.

**First adapters are Cursor (ACP) and Codex (app-server).** Claude and Gemini are documented here so a later adapter is not a fresh research project. They are not the M0 or M1 path.

**Research checked 11 November 2026 (IST); capabilities documented, not device-tested:**

| Agent surface | Supported two-way mechanism | Continuity / cancellation / caveats |
| --- | --- | --- |
| **Claude Agent SDK** | [Streaming input](https://code.claude.com/docs/en/agent-sdk/streaming-vs-single-mode): persistent interactive input, streamed responses and permission handling. Python [`ClaudeSDKClient`](https://code.claude.com/docs/en/agent-sdk/python) supports multi-exchange sessions and `interrupt()`; The [TypeScript reference](https://code.claude.com/docs/en/agent-sdk/typescript) supports streaming `AsyncIterable` input with the streaming Query control interface, including interrupt; use the current SDK reference rather than one-shot CLI output parsing. | Capture explicit session ID and [resume it](https://code.claude.com/docs/en/agent-sdk/sessions). Drain interrupted messages before starting the next response. Do not build on removed experimental V2 `createSession` APIs or assume Python one-off `query()` supports interrupts. SDK usage/auth/branding is not identical to detecting an installed Claude Code CLI. |
| **Codex** | [`codex app-server`](https://developers.openai.com/codex/app-server/), bidirectional JSON-RPC-style requests/server requests and streamed events, default local stdio. | `thread/start` / `thread/resume`, `turn/start`, event/item updates, approval replies, `turn/interrupt` and terminal `turn/completed`. Use the installed version's schema/capabilities. Prefer stdio; no exposed unauthenticated listener. Session history is not filesystem rollback. |
| **Cursor** | Official [CLI ACP](https://cursor.com/docs/cli/acp): `agent acp`, newline-framed JSON-RPC over stdio. | `initialize`, `session/new` / `session/load`, `session/prompt`, `session/update`, `session/request_permission`, `session/cancel`; explicitly answer blocking `cursor/ask_question` and `cursor/create_plan`. Otherwise the agent can wait forever. Ask/plan modes exist; team-level MCP is not supported in ACP per these docs. |
| **Gemini CLI** | Official [ACP mode](https://geminicli.com/docs/cli/acp-mode/): `gemini --acp`, JSON-RPC over stdio; core client methods include new/load session, prompt and cancel. | Negotiate [ACP capabilities](https://agentclientprotocol.com/protocol/session-setup); use wire `session/load` only when advertised. Do not assume optional `session/resume` or `session/close` exists just because the generic protocol defines it. Mode/model changes are capability/version dependent. |

**Distribution is local dogfood until M2.** Auth, the shipping path and the public name are decided then. For dogfood, Cursor and Codex use the login the user already completed in that CLI. Codex app-server auth is acceptable for this local use. [Codex's app-server auth guidance](https://developers.openai.com/codex/app-server/#auth-endpoints) still says that authentication is not permitted for commercial or hosted services; that limit is an M2 question. The [Claude SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) says third-party products need approved auth/API or supported cloud-provider methods, not an assumed right to reuse Claude subscription login/rate limits, and its embedded-agent naming is “Claude Agent”/“Claude”, not “Claude Code”. That constraint matters when Claude becomes an adapter, not for the first two. Never read/copy session tokens or credential files to make an integration work. An adapter with unmet permissions/terms stays unavailable while skills and local Home remain useful.

### Setup and onboarding

Use a compact visual stepper; merge the requested six concerns into four meaningful steps, not six obligatory text pages:

1. **Agents & skills:** official agent-logo cards, CLI installed/version and signed-in verified/unknown states; opt-in checkboxes for the three skills. Install is **whole agent by default**, with a per-project opt-out. It copies the portable skills into that host's skills folder and writes one line in the project's `AGENTS.md`, Cursor rule, or `CLAUDE.md` saying when to use them. It does not install a plugin, register an MCP server, or require a hook. No install writes until final save. Whole-agent scope covers that agent's applicable sessions; it is not permission to clean unrelated personal data. Explain the distinction from the app's project scope. Cursor and Codex are the first cards. Claude and Gemini can appear as unavailable later adapters.
2. **Projects & scope:** suggest directories from permitted agent workspace history/IDE/Git evidence and let the user select/deselect or use a folder picker. Discover projects only inside the selected roots and evidenced related stores. Show caches, builds/environments, worktrees, containers, models and project data as illustrated category cards: **all categories on by default**, individually deselectable. Category inclusion means inspect/manage, never blanket deletion permission. Shared caches remain never preselected as actions.
3. **Guardrails:** never-touch folders; narrow access and Full Disk Access only for an identified need; which coding agent an app run uses (the user picks the agent; Trace does not promise a model picker); Trash/recovery and memory-retention policy; Decide-later notifications; optional background review schedule, off by default, and only while the Trace app is running. There is no menu bar companion. There is no token budget and no time budget. Advanced options expand in place. Do not silently enable an OS notification permission, login item, scheduler or helper that survives quit.
4. **Save & first run:** concise summary of exact install/config scopes, selected roots/categories, per-project opt-outs and the provider boundary. **Save & first run** saves configuration, installs opted-in skills, verifies host trust/activation and starts a read-only first Reviewing pass. It never authorizes Execute. M1's first run only establishes/read-refreshes insights and returns Home. If no agent is ready, saving without running is an explicit fallback. Usage from that pass is shown afterwards, or “unavailable”.

### Run — three stages, one action consent

- **Reviewing:** automatically plan and investigate the selected scope — **one project** or **all permitted Trace projects** — with the agent the user picked, memories and local tools. “All permitted” means every indexed project under the user’s selected roots, never a whole-disk crawl. Show an aesthetic live activity view with factual stages, project/agent identity, coverage and token usage if the agent reported it, not chain-of-thought. There is no budget to exhaust. If the whole-agent skills were opted out for this project, suggest nothing that treats the opt-out as a broken configuration. Respect a prior decline. Replay applicable skills in inspection/memory/proposal mode for observed coverage gaps; do not repeat installations, setup mutations or cleanup silently.
- **Coverage is more than an old timestamp.** Record per-project/per-agent/per-skill version receipts with start/completion time, completed/partial/failed state and covered session/event range. A known session with no completed receipt, a failed integration or a version/scope mismatch can establish a gap. An old date alone, a weekend or missing evidence cannot prove a missed session. Unknown coverage is labelled unknown and can trigger bounded catch-up, not a claim of completeness. Deduplicate concurrent work and never rerun cleanup on a session's already-journaled artifacts merely to fill a gap.
- **Actions:** replace huge file lists with selectable **action cards**. Each card names one understandable operation in a short paragraph and shows estimated/known allocation, safety state, agent/project identity and reversibility. Expand for memory-sourced details, affected-resource manifest, consumers, recreation costs and fresh evidence. Group only artifacts sharing lifecycle, safety and recovery boundaries; separate shared/unknown/protected items. Sensible defaults may select verified, nonshared disposable outputs, never shared/unknown/regret/protected actions.
- **Execute:** the Actions screen's exact selection and effect summary provide the **single explicit execution consent**; do not add another generic “Are you sure?” sheet. Freeze scope, repeat native identity/fingerprint/source/current-use checks at the boundary, skip changed/unsafe items and journal per-card progress/outcomes. Native code owns filesystem Trash actions; agent output cannot invent executable deletion commands or new targets. Result cards distinguish selected allocation, moved-to-Trash bytes and measured free-space change. Offer **Undo via Trash** for exact journaled items, never automatic restore or overwrite. Nonreversible tool-native cleanup stays report-only until a separately approved safety/recovery design exists.

### Home decisions, feedback and optional schedules

Reviewing a Decide-later item uses its existing memory/evidence and a targeted refresh; it need not start a deep Run across the project. Keep/defer needs no model call. If investigation needs the coding agent, the user accepts that scope first, and the result shows usage afterwards. A proposed removal routes to the same selectable Actions/Execute boundary; approving a queue interpretation is not hidden cleanup consent.

Insights are visual cards grouped by project: setup change, skill cleanup outcome, important kept/deferred decision, coverage or recovery attention. Distinguish **skill-originated**, **app-run** and **user-authored** events so the north star can be measured honestly. Details and editable learnings are one expansion away.

Feedback remains local and asymmetric: keep/regret can automatically make recommendations more conservative; more aggressive learned rules require confirmation. A question or dismissed informational card alone is not permission to change policy.

**Optional background schedule is a scoped review, not auto-execution.** Off by default; the user names the project and the coding agent, plus frequency and notification choice. It runs only while the Trace app process is running. Quit stops it. There is no menu bar companion, no helper process afterwards, and a missed slot is not made up by a daemon. Never start a whole-disk scan or Execute. It produces insights, Decide-later items and Actions awaiting the user. Suspend when the agent is unavailable, power or access is unsafe, or other work needs the machine. There is no budget to exhaust.

## 5. Scope

**Anything consuming local storage as part of project work is in scope for understanding and management, not automatically for removal.** This includes agent-created and pre-existing project artifacts:

- Worktrees, generated builds, environments, dependency trees and package/build caches.
- Containers, images, build caches, volumes, development VMs and simulator artifacts.
- Local models, downloaded datasets, checkpoints, generated exports and other data-intensive project surfaces.
- **Shared caches and stores**, even outside project roots. Keep per-project usage notes: known consumers, evidence source/date, recreation method/cost and explicitly unknown consumers. Count shared allocation once. **Never pre-tick shared resources.** Incomplete attribution means keep or further investigation, not unused.

Source code, original datasets, unique checkpoints and persistent volume contents may explain storage but are sources of truth, not expendable artifacts. A named category or logged creation event never establishes safety.

## 6. Non-goals

System-junk cleaning; Mail or Photos cleanup; app uninstall; duplicate-file hunting; a whole-disk size map or whole-Mac categories; CPU/RAM monitoring; silent auto-clean; automatically emptying Trash; cloud memory sync; copying competitors' implementations.

No mandatory Full Disk Access as an inherited onboarding step: request only access justified by the chosen project/store. The minimum system is macOS 14. That is a product decision, not a carried-over Shed requirement.

## 7. Memory: evidence first, compact lessons second

**Research basis.** Anthropic's [The components of agent memory](https://www.anthropic.com/research/components-of-agent-memory), published 6 November 2026, distinguishes session evidence, salient notes, navigable representations and a small injected layer. It shows why notes need source checks and corrections, why indiscriminate memory can become stale overhead, and why a wiki is not automatically better than search. This is the recent article found in Gopi's reading conversation with Sage; it is not evidence that Trace's design already works.

**Trace's proposed application, not an Anthropic-prescribed schema:**

- Preserve storage-relevant events as an append-only local provenance ledger; use explicit correction/supersession events rather than silently rewriting history.
- Maintain a compact project index and a small set of linked lifecycle/learning notes. Keep live facts such as current size in refreshed inventory instead of duplicating them as permanent beliefs. Retrieve details on demand; do not inject the entire history.
- Separate **observed**, **inferred** and **verified** claims. A lesson includes its evidence, conditions and last verification; a failed hypothesis does not become a rule just because it was written down. Preserve successful practices as well as failures.
- At a user-invoked review, approved scheduled review or session boundary, optionally reconcile notes against permitted original evidence: correct errors, merge redundancy and mark stale dependencies. This borrows the article's “dreaming” idea without committing to an always-on background process or unlimited compute.
- Memory remains advisory and untrusted as an action instruction. It never overrides protected paths, current dependencies or user consent. Retention, deduplication and maintenance must keep Trace from becoming another source of bloat.

### Minimum artifact-log contract

| Field | Meaning |
| --- | --- |
| `what` | Stable artifact/resource ID, kind, canonical location or tool-native ID; measured bytes and completeness when available. |
| `why` | Task/purpose and why it needs to persist, or why it is temporary. |
| `agent` | Harness and session identity. `unknown` only after the deep attribution pass still cannot name a creator. A path name is not attribution. |
| `project` | Stable project identity and owning/consuming projects; shared resources retain multiple consumers and uncertainty. |
| `created` | Creation timestamp with timezone and evidence source; distinguish observed creation from inferred age or first discovery. Unknown stays unknown. |
| `can_go_when` | Explicit lifecycle condition, such as a completed task and no remaining consumers; never age alone. |

**Proposed supporting fields:** schema/event version, event ID, observed/verified time, evidence references, last known use, tool/version, recreation recipe/cost, confidence, dependency notes, correction link and cleanup/restore outcome. Add redacted before/after setup-change events, stable Decide-later references and per-skill coverage receipts as specified above; a single last-run timestamp is not sufficient. Store redacted recipes rather than secret-bearing raw shell commands. Recipes are explanations, not authority to execute them.

**Privacy.** Keep the ledger, the project index and preferences local. Skills append to a per-project log. The app is the only writer of its database. Skills also keep the index that points the app at each project's log. No file bodies, credentials or raw command output in them. Access to original session evidence is explicit and scoped, not bulk transcript ingestion. Explain that invoking the user's coding harness may send permitted context to its configured provider; “local memory” does not mean local inference. Redact/minimize outbound context and disclose the chosen boundary.

## 8. Safety principles — carried forward, not old code

1. **Never-delete protections.** Protect system trees and volume roots; personal Documents, Photos and Mail; secrets and credentials; primary source checkouts, tracked/untracked user source, original/only-copy data; and the editable never-touch list. A protected ancestor cannot be selected as one bulk cleanup target. A generated artifact inside an eligible repository is assessed separately; the repository itself is not disposable. Protected/unknown findings may explain space, but stay locked or unticked.
2. **Same three questions for every candidate:** what does recreation cost, what depends on it now, and is it a source of truth? Unknown or incomplete safety evidence means keep pending verification. Stale age, a familiar folder name, `.gitignore` or an AI judgment is never enough.
3. **Fresh boundaries.** Restrict investigation/actions to approved project roots and evidenced related stores. Use component-aware canonical ancestry, never follow symlink escapes, and reject protected aliases. Check identity, fingerprint, tracked-source state and current use at the explicit Actions consent boundary and immediately before Trash. A changed item is skipped and reviewed again. If full safety validation cannot finish, do not act.
4. **Git and live state.** Keep dirty, untracked, unmerged, linked or uncertain worktrees protected pending the Git-aware flow in [ADR-0009](adr/0009-git-aware-worktree-flow.md): merged against the fetched remote default branch, clean, not in use, ignored files accounted for, then Trash + `worktree prune` with admin-dir journaling for undo — never `git worktree remove`. Do not remove open/in-use artifacts. Inability to establish use is not proof of non-use.
5. **Trash, not `rm`.** Obtain one explicit consent for an immutable Actions selection and move eligible filesystem items to Trash, with a durable action/restore journal. Never empty Trash automatically. Restore only with consent and never overwrite an existing destination. Container volumes and other tool-native removals may not be reversible: keep them report-only in `trace-out/report.json` ([ADR-0010](adr/0010-report-only-channel.md)) until a separately approved recovery/action design exists — not as Decide-later `kept`, and not as Trash proposals. Never Trash Docker's VM disk or a package/model store's internals to simulate supported cleanup.
6. **Honest results.** Selected allocated size, bytes moved to Trash, tool-reported reclaimed space and measured free-space change are different values. Shared APFS blocks, snapshots and Trash prevent exact promises. Post-clean checks report passed, failed or incomplete; say “couldn't verify” rather than “everything works” without evidence. Verification that executes project code or rebuilds storage needs disclosure and consent.
7. **Bounded work, no premature constants.** Limit subprocess output, work queues, memory and model context; keep filesystem work off the UI thread. Show partial coverage and skipped counts. Stuck-session deadlines exist so a hung helper can be killed. They are not a token budget, and Trace does not set one. Do not import whole-disk benchmark gates.

## 9. Success metrics

**Approved north star:** **70% of the bytes of agent-created artifacts are removed within 30 days of creation, with zero regrets.** This is a target, not a measured result. Zero regrets means no lost work, cleanup-caused breakage or removal the user wishes had not happened; a restore request counts even when recovery succeeds.

**Measurement, locked:** the denominator is bytes of artifacts an agent created. The numerator is the bytes among them removed within 30 days of creation. Removal means an approved action took the artifact out of the working set, including a move to Trash. Shared caches count once on each side. Measured free-space change is always shown separately and is never this percentage. Attribute skill-driven removal and app-driven removal separately so the “without the app” part of the older wording can still be seen, but the percentage itself does not require the app to have been closed.

**Creators are searched for before they are called unknown.** The coding agent runs a deep attribution step over git history, file timestamps, agent session logs and transcripts, package and lock metadata, and the tool's own manifests. Whatever it can attribute with evidence gets a source in memory, the evidence ids, and a `verified` or `inferred` label, and those bytes count. A path or folder name is not evidence. A known human creator is recorded and stays out of the agent-created ratio. Only bytes still unknown after that pass stay out of both sides and are reported separately, with the sources that were checked. [ADR-0003](adr/0003-attribution-and-cursor-pin.md).

Supporting measures, initially baselines rather than invented targets:

- **Provenance coverage:** share of project-work bytes with useful purpose, ownership, lifecycle and recreation evidence; report unknown bytes explicitly.
- **Everyday overhead and catch-up effort:** Home should need no model call to render; measure skill overhead, Decide-later resolution effort and deep-run tokens versus comparable first/repeat work. These are baselines, not invented performance results.
- **Recommendation quality:** kept/unticked rate and regret/restore rate, with reasons; savings never outweigh a safety regression.
- **Ask usefulness and usage:** source-backed memory-only answer share, unresolved/conflicting questions, escalation usage when the agent reported it, and user review effort. No target percentage invented before dogfood.
- **Session reliability:** completion/partial/cancel/timeout outcomes, orphaned owned work, correct scoped resume and duplicate/mutating replay incidents; bidirectionality is not itself proof of reliability.

## 10. Milestones and learning approach

### M0 — skills + Decide-later queue

Dogfood the three working skills in Gopi's Cursor and Codex sessions, with a per-project log, the skill-maintained project index, setup-change and decision events, coverage receipts and a durable deduplicated Decide-later queue. Review queued choices through the harness before the app exists. Install is the host skills folder plus the one instruction line, whole agent by default, with a per-project opt-out. Hooks stay off unless Gopi opts in. Validate host installation, whether the instruction line is what makes the skill run, task friction and the 30-day metric. No app dependency for everyday hygiene. Claude is not an M0 harness.

Ship dogfood as complete loops: M0 skills (Record, Doubt, Cleanup, Prevent), then the native macOS app shell (Home, Setup, memory-only Ask). [ADR-0005](adr/0005-m0-phases-complete-loops.md), [dogfood-plan.md](dogfood-plan.md).

### M1 — Setup + Home insights, cleanup read-only

Build the visual onboarding/Setup, project-root/category controls, per-agent/per-project installation, Home's top queue and project insight cards, memory editing, **memory-only Ask Trace** and truthful coverage. First-run inspection can establish a legacy baseline and populate insights with disclosed tokens; its app-agent path already needs the required two-way session foundation, not fire-and-forget plumbing deferred to M2. App action/recovery history can explain skill outcomes, but the app does not execute cleanup yet. Home itself reads locally and stays useful offline. Verify official-logo permissions and accessible card prototypes before broader distribution.

### M2 — Run: Reviewing → Actions → Execute

Extend and validate the bidirectional session foundation on Cursor ACP and Codex app-server, add **agent-escalated Ask Trace**, then add the on-demand deep/catch-up pass, gap-aware skill review, live activity cards, selectable action cards, the single consent boundary, guarded Trash execution, honest outcome cards and explicit Undo/restore. Show usage. Do not add a token cap. Start with reversible filesystem artifacts. The optional review runs only while the Trace app is running; no menu bar companion, no helper after quit, and no scheduled Execute. Auth, distribution and the public name are decided here, not before. Claude and Gemini stay later adapters until these two hold the session contract. Codex app-server's commercial auth limits are part of the distribution decision, not a reason to avoid it for local dogfood.

**No hard tests locked up front — tests added only when behavior stabilizes.** Do not port Shed's test suite, architecture assertions, fixtures, numeric scan gates or code scaffold. Use small experiments, manual dogfood and disposable fixtures while behavior is moving; add focused regressions for stable behavior and observed failures. This is not permission to experiment destructively on user data: cleanup ships only after its safety boundary and recovery are demonstrated on disposable artifacts.

## 11. Design & UX

The companion [Design & UX specification](design.md) is the end-to-end presentation/interaction source of truth: card/imagery-first Setup, default Home with Decide later, the three-stage Run, official-agent logo constraints, a full Laws-of-UX mapping and native-first per-screen component kit, memory-first Ask Trace and resumable two-way-session states, plus memory, recovery, accessibility and all failure states. This PRD owns product scope and safety. Visual dimensions/tokens and unvalidated behavior are marked proposed, not hard tests frozen before implementation.

## 12. Assumptions and how to validate

| Assumption — not established research | Validation |
| --- | --- |
| Agents can record useful ownership/lifecycle evidence without disrupting the task. | M0: inspect real Cursor and Codex sessions, missed artifacts, extra turns and user friction. |
| Suggested directories plus explicit root selection find active projects without a whole-disk crawl. | M1: compare with Gopi's actual projects; inspect misses, nested/overlapping roots and inaccessible locations. |
| Shared-store consumers can be attributed well enough to support a decision. | M0/M1: compare notes with actual tool metadata across projects; deliberately test missing/unknown consumers. |
| Local Home insights and receipts avoid unnecessary deep runs while catch-up remains reliable. | M0/M2: compare actual host sessions to receipts; test a missed session, including an opted-in hook that did not run, plus sleeping/offline periods, scope changes and concurrent work; measure model use versus missing evidence. |
| Project-directed storage hygiene is valuable beyond Gopi. | After personal dogfood, run a small voluntary trial; observe real cleanup decisions rather than inventing market evidence. |

## 13. Locked decisions, and what is still open

Locked by Gopi on 11 November 2026. The record is [ADR-0002](adr/0002-locked-product-decisions.md).

1. **Skill autonomy.** Skills run inside the coding agent while it works. Before any cleanup or install, the skill nudges the user and asks. It researches the healthiest, most efficient way and adds the steps to the agent's own task checklist. It records the decision in project memory and follows it next time. It may remove something without asking again only when the user approved that exact item before. Everything else is asked about, or goes to Decide-later.
2. **Install scope.** Whole agent by default, with a per-project opt-out.
3. **Budgets.** None for now. Show what each Run or Ask used. Memory first. No budget settings.
4. **70% target.** Bytes of agent-created artifacts removed within 30 days of creation. Shared caches count once. Measured free space is always shown separately and is never the metric.
5. **Storage.** Everything stays local. Skills append to a per-project log. The app is the only writer of its database. Skills keep an index of projects and where their memory files are. The index path in the engineering doc is directional.
6. **Background runs.** Only while the Trace app process is running. No menu bar companion. No helper after quit.
7. **Distribution.** Local dogfood only. Auth, distribution and the public name are decided at M2.
8. **First agents.** Cursor (ACP) and Codex (app-server). Claude and Gemini come later. Codex app-server is fine for local dogfood; its commercial auth limits are an M2 question.
9. **Models.** The user picks the coding agent for an app-triggered run. Skills are evaluated across that agent's available models to name a best-value model per agent, scored on the model that actually ran. If only some models handle a skill well, the skill may ask for that model in a subagent. On Cursor the pin is a preference, never a gate. The skill always runs. A mismatch is not a failure. When the pin does not stick, the skill is **best effort on Cursor**.
10. **Minimum macOS** is 14.

How those skills are packaged is [ADR-0004](adr/0004-skills-not-a-plugin.md): three portable Agent Skills, one shared core, one project line saying when to use them, optional hooks, no MCP, and a plugin only later as a thin wrapper.

Still open, and not decided by that list:

- Which model id is best value for Cursor, and which for Codex. The rule is locked, including that a Cursor pin is only a preference. The pick waits on live evals scored against the model that actually ran, and on the agent reporting usage.
- The M2 choice of auth, distribution and public name.
- What evidence completes a shared-consumer list, and which tool-native actions can be undone.
- How long memory and journal rows are kept.
- Which judge model the evals use, and when a person labels the dev set.

## 14. What survives Shed — and what does not

**Reuse the lessons:** provenance over guesses; recreation/dependency/criticality checks; the never-touch list; confirm/action-time identity checks; Trash and explicit recovery; conservative defaults; editable preferences with asymmetric learning; bounded agent/tool output; visible cancellation/partial coverage; honest space accounting.

**Drop the product and implementation baggage:** the whole-disk Pass 2, full-computer directory index/treemap ambitions, whole-Mac categories, system-junk scope, whole-Mac onboarding/FDA assumptions, text-heavy artifact-list review, Run-as-default-home, the 1-million-entry/60-second release benchmark and its inherited hard resource/test gates. Do not copy Shed's code or tests into the fresh repository. Details that are not in the firm rules stay guesses. Trace does not carry Shed's numeric budgets forward, and it does not add its own.

## Sources and evidence boundaries

- **Product decisions:** Gopi's scope/reset/name decisions and UI/skills/app refinement (t120u and t121u) in the 11 November 2026 conversation: all project-work storage including shared caches; skills-first; opt-in agent/project skill scope, selectable project roots/categories, Home insights and Decide later, gap-aware three-stage app Run, memory-first Ask Trace and required resumable two-way agent sessions; memory reuse later; 70%/zero-regrets target; fresh project named Trace, not a rewrite constrained by Shed's tests.
- **Memory research:** Anthropic, [The components of agent memory](https://www.anthropic.com/research/components-of-agent-memory), 6 November 2026. Read in full for this draft; Trace-specific schema and maintenance choices above are proposals, not claims made by the article.
- **Prior product/safety material read:** [Shed PRD](https://github.com/gksoriginals/shed/blob/main/docs/prd.md), [UX](https://github.com/gksoriginals/shed/blob/main/docs/ux.md), [implementation/evidence ledger](https://github.com/gksoriginals/shed/blob/main/docs/implementation.md), and README on `main`. These contain historical, sometimes conflicting architecture descriptions; only the explicitly retained principles carry forward.
- **Prior scan research read:** `shed-scan-research.md`, research dated 8 November 2026 (IST), available on the working box at `/workspace/shed-scan-research.md`. Useful for path safety, accounting and bounded exploration; its whole-disk architecture and proposed benchmark numbers are not Trace requirements. It reports public documentation/source research, not a reverse-engineering proof of proprietary internals. Borrow techniques, not license-restricted implementation code.
- **Name-check evidence:** existing [Trace AI-agent analytics](https://traceanalytics.vercel.app/) and [Trace macOS meeting app with tracecli](https://traceapp.info/), checked 11 November 2026 (IST). Additional collisions include [Trace CLI for PCB development](https://docs.buildwithtrace.com/resources/cli/) and [IONSEC TRACE](https://ionsec.github.io/trace/), which uses the `trace` command. This is a discoverability check, not legal trademark clearance.
