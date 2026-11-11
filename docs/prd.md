# Trace — PRD v0.1

**Status:** fresh-start product draft · **Owner:** Gopi · **Date:** 11 November 2026 (IST)

Trace is the chosen working name. A closely adjacent AI-agent analytics app and another macOS app already use it; qualify or revisit the public name before launch. Do not assume an unqualified `trace`, `trace-cli` or `tracecli` command is available. This document defines a new product, not another phase of Shed.

## 1. One-line pitch

**Trace keeps project work from filling your Mac: skills help coding agents leave less behind, and a small app turns what remains into an evidence-backed cleanup.**

## 2. Why

**Problem.** Project work accumulates builds, environments, dependencies, worktrees, containers, models and data. A cleaner inspecting them afterward cannot reliably know why they exist, what still depends on them or what it costs to recreate them. Age and size are not proof of disposability.

**Why now — product hypothesis, not user research.** Coding agents both create this storage and know the task that created it. Capture that context during work rather than reconstructing it from filenames later.

**Why skills beat cleaners.** Hygienic setup prevents unnecessary copies and unmanaged installations. Session-end cleanup resolves temporary leftovers while context is fresh. Memory preserves the reason for everything that must remain. The app is the review and recovery surface, not the primary cleanup engine.

## 3. Who

Start with Gopi using Claude Code and Codex on his Mac, across coding projects and data-intensive work surfaces. Expand to other agent-heavy developers only after dogfood establishes usefulness and trust. No interviews, market-size claims or measured user outcomes are assumed.

## 4. What

### Three installable skills, each with one job

1. **Hygienic setup — prevent avoidable storage.** Before installing tools, building, creating environments or starting containers, consult current official documentation for the task and tool version. Prefer scoped, reproducible setups, explicit lifecycle/ownership and appropriate reuse over unmanaged global installs or duplicate downloads. Explain storage/recreation tradeoffs; do not assume a container is always smaller or that a shared cache is always best. Record what the chosen setup creates through the memory writer. No additional tool-specific skill should be required just to cover a new artifact type.
2. **Session-end cleanup — resolve this session's leftovers.** Review what the session created and what must persist. Propose removal of short-lived artifacts, explain dependencies and recovery, and ask before acting. Perform only the cleanup the user approves, using the same safety rules as the app. Log what was kept, cleaned, skipped or could not be verified. Skills doing the work means agent-driven cleanup with consent, not silent deletion.
3. **Memory writer — preserve reusable storage knowledge.** Record artifact provenance and lifecycle decisions, plus salient verified lessons that help future setup and cleanup. Keep observed facts separate from guesses. Record evidence and corrections, not every command or every file. The machine-readable ledger supports the app; compact human-readable notes support future agent sessions.

Skills must work without the app. Harness-specific packaging and hooks are adapters, not separate products. Validate the current supported installation mechanism in each harness; do not inherit Shed's old hook contracts as facts.

### The app — discover → bootstrap → remember → review

- **Discover projects automatically.** Use permitted local agent workspace metadata/history, IDE recents and Git-root evidence to find the user's active projects and data-intensive work surfaces. Show where each project came from; allow exclude, correct and manually add as escape hatches, not required onboarding. Discovery is bounded and project-directed, never a disguised whole-home or whole-disk crawl. Known project-owned stores outside a repository are included through provenance/configuration evidence.
- **First run on a project.** Suggest installing the three skills into the selected coding agent. Explain and obtain consent for installation/config changes and the project agent run. The agent inventories that project's artifacts and related shared stores using its tools, researches uncertain lifecycle behavior and writes a baseline memory. Existing storage is inferred inventory, not retroactively claimed to have been created by that agent. If installation is declined or the agent is unavailable, explain what is blocked; do not invent a completed report.
- **Later runs.** Load a small project-memory index, retrieve only relevant evidence and refresh what changed. Recheck live dependencies, identity and safety; a memory is not a deletion permit. Investigate changed or unknown areas instead of repeating an unrestricted scan.
- **Review and Trash.** Show project, item, measured size/completeness, why it exists, why removal is proposed, what could break and how to recreate it. Distinguish remove, keep/protected and unknown. Only selected items pass through a confirmation sheet and fresh action checks. Native code owns filesystem Trash actions; an agent response cannot introduce arbitrary executable deletion commands or unreviewed paths. Tool-managed resources use a separately disclosed, exact tool-native action rather than raw deletion of their stores.
- **Feedback loop.** Keep decisions, regrets, restore requests, dismissed nudges and scoped questions locally. Turn useful patterns into plain-language learnings the user can inspect, edit, disable or delete. Feedback may make behavior more conservative automatically; any more aggressive rule needs confirmation. A question alone is not permission to change policy.
- **On demand and interruptible.** Show the stage, counts, partial/skipped coverage and a working Stop control for discovery, agent work and cleanup. Do not fake a percentage for an unknown workload. Cancellation cannot undo completed moves; journal them and report what happened. No always-on storage crawler.

## 5. Scope

**Anything consuming local storage as part of project work is in scope for understanding and management, not automatically for removal.** This includes agent-created and pre-existing project artifacts:

- Worktrees, generated builds, environments, dependency trees and package/build caches.
- Containers, images, build caches, volumes, development VMs and simulator artifacts.
- Local models, downloaded datasets, checkpoints, generated exports and other data-intensive project surfaces.
- **Shared caches and stores**, even outside project roots. Keep per-project usage notes: known consumers, evidence source/date, recreation method/cost and explicitly unknown consumers. Count shared allocation once. **Never pre-tick shared resources.** Incomplete attribution means keep or further investigation, not unused.

Source code, original datasets, unique checkpoints and persistent volume contents may explain storage but are sources of truth, not expendable artifacts. A named category or logged creation event never establishes safety.

## 6. Non-goals

System-junk cleaning; Mail or Photos cleanup; app uninstall; duplicate-file hunting; a whole-disk size map or whole-Mac categories; CPU/RAM monitoring; silent auto-clean; automatically emptying Trash; cloud memory sync; copying competitors' implementations.

No mandatory Full Disk Access as an inherited onboarding step: request only access justified by the chosen project/store. Permissions and minimum macOS version are implementation decisions to validate, not carried-over Shed requirements.

## 7. Memory: evidence first, compact lessons second

**Research basis.** Anthropic's [The components of agent memory](https://www.anthropic.com/research/components-of-agent-memory), published 6 November 2026, distinguishes session evidence, salient notes, navigable representations and a small injected layer. It shows why notes need source checks and corrections, why indiscriminate memory can become stale overhead, and why a wiki is not automatically better than search. This is the recent article found in Gopi's reading conversation with Sage; it is not evidence that Trace's design already works.

**Trace's proposed application, not an Anthropic-prescribed schema:**

- Preserve storage-relevant events as an append-only local provenance ledger; use explicit correction/supersession events rather than silently rewriting history.
- Maintain a compact project index and a small set of linked lifecycle/learning notes. Keep live facts such as current size in refreshed inventory instead of duplicating them as permanent beliefs. Retrieve details on demand; do not inject the entire history.
- Separate **observed**, **inferred** and **verified** claims. A lesson includes its evidence, conditions and last verification; a failed hypothesis does not become a rule just because it was written down. Preserve successful practices as well as failures.
- At a user-invoked review or session boundary, optionally reconcile notes against permitted original evidence: correct errors, merge redundancy and mark stale dependencies. This borrows the article's “dreaming” idea without committing to an always-on background process or unlimited compute.
- Memory remains advisory and untrusted as an action instruction. It never overrides protected paths, current dependencies or user consent. Retention, deduplication and maintenance must keep Trace from becoming another source of bloat.

### Minimum artifact-log contract

| Field | Meaning |
| --- | --- |
| `what` | Stable artifact/resource ID, kind, canonical location or tool-native ID; measured bytes and completeness when available. |
| `why` | Task/purpose and why it needs to persist, or why it is temporary. |
| `agent` | Harness and session identity; `unknown` for legacy inventory without reliable attribution. |
| `project` | Stable project identity and owning/consuming projects; shared resources retain multiple consumers and uncertainty. |
| `created` | Creation timestamp with timezone and evidence source; distinguish observed creation from inferred age or first discovery. Unknown stays unknown. |
| `can_go_when` | Explicit lifecycle condition, such as a completed task and no remaining consumers; never age alone. |

**Proposed supporting fields:** schema/event version, event ID, observed/verified time, evidence references, last known use, tool/version, recreation recipe/cost, confidence, dependency notes, correction link and cleanup/restore outcome. Store redacted recipes rather than secret-bearing raw shell commands. Recipes are explanations, not authority to execute them.

**Privacy.** Keep the ledger and preferences local; no file bodies, credentials or raw command output in them. Access to original session evidence is explicit and scoped, not bulk transcript ingestion. Explain that invoking the user's coding harness may send permitted context to its configured provider; “local memory” does not mean local inference. Redact/minimize outbound context and disclose the chosen boundary.

## 8. Safety principles — carried forward, not old code

1. **Never-delete protections.** Protect system trees and volume roots; personal Documents, Photos and Mail; secrets and credentials; primary source checkouts, tracked/untracked user source, original/only-copy data; and the editable never-touch list. A protected ancestor cannot be selected as one bulk cleanup target. A generated artifact inside an eligible repository is assessed separately; the repository itself is not disposable. Protected/unknown findings may explain space, but stay locked or unticked.
2. **Same three questions for every candidate:** what does recreation cost, what depends on it now, and is it a source of truth? Unknown or incomplete safety evidence means keep pending verification. Stale age, a familiar folder name, `.gitignore` or an AI judgment is never enough.
3. **Fresh boundaries.** Restrict investigation/actions to approved project roots and evidenced related stores. Use component-aware canonical ancestry, never follow symlink escapes, and reject protected aliases. Check identity, fingerprint, tracked-source state and current use at confirmation and immediately before Trash. A changed item is skipped and reviewed again. If full safety validation cannot finish, do not act.
4. **Git and live state.** Keep dirty, untracked, unmerged, linked or uncertain worktrees protected pending a dedicated Git-aware flow. Do not remove open/in-use artifacts. Inability to establish use is not proof of non-use.
5. **Trash, not `rm`.** Confirm an immutable selection and move eligible filesystem items to Trash, with a durable action/restore journal. Never empty Trash automatically. Restore only with consent and never overwrite an existing destination. Container volumes and other tool-native removals may not be reversible: keep them report-only until a separately approved recovery/action design exists. Never Trash Docker's VM disk or a package/model store's internals to simulate supported cleanup.
6. **Honest results.** Selected allocated size, bytes moved to Trash, tool-reported reclaimed space and measured free-space change are different values. Shared APFS blocks, snapshots and Trash prevent exact promises. Post-clean checks report passed, failed or incomplete; say “couldn't verify” rather than “everything works” without evidence. Verification that executes project code or rebuilds storage needs disclosure and consent.
7. **Bounded work, no premature constants.** Limit subprocess output, work queues, memory, elapsed time and model context; keep filesystem work off the UI thread. Show partial coverage and skipped counts. Determine concrete budgets from project dogfood rather than importing whole-disk benchmark gates.

## 9. Success metrics

**Approved north star:** **70% of agent-created storage cleaned up by the skills without the app, with zero regrets.** This is a target, not a measured result. Zero regrets means no lost work, cleanup-caused breakage or removal the user wishes had not happened; a restore request counts even when recovery succeeds.

**Proposed measurement:** use a deduplicated cohort of completed agent sessions. Attribute confirmed cleanup bytes to skill-driven sessions versus app-driven cleanup; do not count the same artifact or shared allocation repeatedly, and do not call Trash bytes reclaimed free space. Record required-to-persist artifacts and unknown attribution separately. Lock the denominator, observation window and treatment of intentionally persistent storage during M0 so the 70% target cannot be gamed by ignoring difficult cases.

Supporting measures, initially baselines rather than invented targets:

- **Provenance coverage:** share of project-work bytes with useful purpose, ownership, lifecycle and recreation evidence; report unknown bytes explicitly.
- **Repeat-run effort:** time, agent turns/tokens and user review effort for a returning project versus its first run on comparable work.
- **Recommendation quality:** kept/unticked rate and regret/restore rate, with reasons; savings never outweigh a safety regression.

## 10. Milestones and learning approach

### M0 — skills only, dogfood in Gopi's Claude Code and Codex

Ship the three skills and the smallest portable ledger/index. Try real setup → work → cleanup → next-session reuse. Check current installation/trust behavior in both harnesses, inspect provenance gaps and validate the metric definition. Do not build the app to compensate for skills that are not yet useful.

### M1 — app as a read-only project report

Automatically discover/correct projects, suggest skill installation, run the first-project agent bootstrap with consent and reuse memories on subsequent reports. Show project/shared-store evidence, uncertainty and proposed actions. No app cleanup yet. Compare first and repeat runs; evaluate whether the memories actually reduce investigation.

### M2 — confirmed cleanup and recovery

Add the review/confirmation boundary, native Trash guard, action journal, explicit restore and honest result checks. Begin with reversible filesystem artifacts. Introduce tool-native cleanup only after its resource-specific safety and recovery story is understood. Expand supported harnesses based on evidence, not a precommitted matrix.

**No hard tests locked up front — tests added only when behavior stabilizes.** Do not port Shed's test suite, architecture assertions, fixtures, numeric scan gates or code scaffold. Use small experiments, manual dogfood and disposable fixtures while behavior is moving; add focused regressions for stable behavior and observed failures. This is not permission to experiment destructively on user data: cleanup ships only after its safety boundary and recovery are demonstrated on disposable artifacts.

## 11. Design & UX

The companion [Design & UX specification](design.md) defines the complete app experience: visual language, light/dark tokens, typography, layout, accessibility, menu bar, first launch, project bootstrap, repeat reports, review/confirmation/Trash, results/recovery, editable memory, feedback, settings and failure states. Commit it as `docs/design.md` beside this PRD. It is the presentation/interaction source of truth; this PRD owns product scope and safety. Proposed dimensions and tokens are starting decisions to dogfood, not hard tests frozen before implementation.

## 12. Assumptions and how to validate

| Assumption — not established research | Validation |
| --- | --- |
| Agents can record useful ownership/lifecycle evidence without disrupting the task. | M0: inspect real Claude/Codex sessions, missed artifacts, extra turns and user friction. |
| Workspace metadata can find the active project set without a whole-disk crawl. | M1: compare discovery with Gopi's own active-project list; inspect misses, false positives and inaccessible locations. |
| Shared-store consumers can be attributed well enough to support a decision. | M0/M1: compare notes with actual tool metadata across projects; deliberately test missing/unknown consumers. |
| Compact memory plus targeted refresh makes repeat runs cheaper without trusting stale facts. | M1: compare first/repeat reports after edits, renames, dependency changes and concurrent work; inspect stale claims and cost. |
| Project-directed storage hygiene is valuable beyond Gopi. | After personal dogfood, run a small voluntary trial; observe real cleanup decisions rather than inventing market evidence. |

## 13. Open questions

1. **Measurement:** what exactly is the 70% denominator and observation window, especially for persistent artifacts, legacy inventory, shared allocation and Trash versus physically reclaimed bytes?
2. **Shared resources:** what evidence establishes all current consumers, and which tool-native cleanup operations can offer an acceptable recovery story? Unknown consumers remain protected meanwhile.
3. **Memory contract:** where do the portable ledger and notes live, how are concurrent writers/corrections handled, and what retention/maintenance budget prevents memory bloat?
4. **Consent and privacy:** what minimal permissions, harness context and user confirmations make first-run bootstrap and later refresh useful without overexposing project data? What should a declined install permit?
5. **Project lifecycle and naming:** how do we identify active, renamed, moved, archived and non-Git work surfaces reliably; and should the public product use a qualified Trace name to avoid existing adjacent apps?

## 14. What survives Shed — and what does not

**Reuse the lessons:** provenance over guesses; recreation/dependency/criticality checks; the never-touch list; confirm/action-time identity checks; Trash and explicit recovery; conservative defaults; editable preferences with asymmetric learning; bounded agent/tool output; visible cancellation/partial coverage; honest space accounting.

**Drop the product and implementation baggage:** the whole-disk Pass 2, full-computer directory index/treemap ambitions, whole-Mac categories, system-junk scope, whole-Mac onboarding/FDA assumptions, the 1-million-entry/60-second release benchmark and its inherited hard resource/test gates. Do not copy Shed's code or tests into the fresh repository. Architecture and budgets emerge from this scope's experiments.

## Sources and evidence boundaries

- **Product decisions:** Gopi's scope/reset/name decisions in the 11 November 2026 conversation: all project-work storage including shared caches; skills-first; first-run install suggestion plus agent bootstrap; memory reuse later; 70%/zero-regrets target; fresh project named Trace, not a rewrite constrained by Shed's tests.
- **Memory research:** Anthropic, [The components of agent memory](https://www.anthropic.com/research/components-of-agent-memory), 6 November 2026. Read in full for this draft; Trace-specific schema and maintenance choices above are proposals, not claims made by the article.
- **Prior product/safety material read:** [Shed PRD](https://github.com/gksoriginals/shed/blob/main/docs/prd.md), [UX](https://github.com/gksoriginals/shed/blob/main/docs/ux.md), [implementation/evidence ledger](https://github.com/gksoriginals/shed/blob/main/docs/implementation.md), and README on `main`. These contain historical, sometimes conflicting architecture descriptions; only the explicitly retained principles carry forward.
- **Prior scan research read:** `shed-scan-research.md`, research dated 8 November 2026 (IST), available on the working box at `/workspace/shed-scan-research.md`. Useful for path safety, accounting and bounded exploration; its whole-disk architecture and proposed benchmark numbers are not Trace requirements. It reports public documentation/source research, not a reverse-engineering proof of proprietary internals. Borrow techniques, not license-restricted implementation code.
- **Name-check evidence:** existing [Trace AI-agent analytics](https://traceanalytics.vercel.app/) and [Trace macOS meeting app with tracecli](https://traceapp.info/), checked 11 November 2026 (IST). Additional collisions include [Trace CLI for PCB development](https://docs.buildwithtrace.com/resources/cli/) and [IONSEC TRACE](https://ionsec.github.io/trace/), which uses the `trace` command. This is a discoverability check, not legal trademark clearance.
