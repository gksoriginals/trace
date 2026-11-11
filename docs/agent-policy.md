## Requirements, tests, and changing approach

- Read the current user-approved requirements, relevant design decisions,
  implementation, and tests before editing. Identify conflicting or stale
  documents; ask if the intended behavior is unclear.
- Existing code and tests describe the current system, not necessarily the
  required design. Preserve required behavior, security, data safety, and
  compatibility commitments, not incidental implementation details.

### Before substantial changes
- Write a short plan: intended outcomes, constraints, approach, affected
  contracts, and verification commands.
- Classify relevant tests as:
  1. Acceptance/contract: externally required behavior or invariants.
  2. Implementation-coupled: internal structure, mocks, call order, snapshots.
  Classify by intent, not filename or test framework.

### Changing tests
- Do not weaken, skip, delete, or change expectations merely to obtain green.
- You may rewrite or remove implementation-coupled tests when the
  implementation is intentionally replaced. State why each test is obsolete
  and preserve its meaningful behavioral coverage.
- Before changing a test, cite the requirement or approved decision that
  justifies it and describe the replacement verification.
- If a change alters an acceptance contract, security invariant, data-safety
  rule, or compatibility promise, get explicit approval first.
- An unexplained failure is evidence to investigate, not permission to edit
  the test. Separate regressions, stale tests, and environment failures.

### Avoid repair loops
- After 3 unsuccessful attempts on the same failure, stop patching.
  Summarize the evidence, reassess the requirement and assumptions, and
  propose a materially different approach or ask for a decision.
- Do not repeat the same failed command without new evidence.
- For uncertain architecture, use an isolated, time-boxed spike with an
  explicit question and success criteria. Label it non-production; record
  whether to discard it or promote a reviewed implementation.

### Record and verify
- For architectural changes, record a brief ADR/decision log: context,
  alternatives, decision, rationale, consequences, and superseded decision.
- Run focused tests, relevant regression/acceptance checks, and applicable
  build/type/lint checks. Verify observable behavior against requirements.
- Report commands and results, tests changed and why, unresolved failures,
  and requirements not yet verified. Never claim success from green tests
  alone.
