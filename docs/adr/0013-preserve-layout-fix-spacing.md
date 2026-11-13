# ADR-0013: Preserve the existing layout; fix spacing

## Context

The owner requested less wasted space and better usability, using the running app rather than the outdated Pencil design. During review, the owner explicitly preferred the original UI over a proposed labeled top navigation and expanded Home overview.

## Decision

Preserve the right icon rail, original Home card grid, Add folder tile, and existing information hierarchy. Remove the project-card width ceiling so columns use available width, widen the project-detail reading column, and reduce its section gaps. Preserve Settings form styling while removing redundant outer padding, labeling the protected-path editor, and keeping Apply reachable when scrolling.

## Alternatives and consequences

Reject the proposed top navigation, additional Home overview/recent-run sections, and extra project action buttons. Do not fill sparse accounts with invented content or automatic agent work. No changes to cleanup, agent sessions, data formats, or skill installation contracts. This records the owner's correction to this task, not a broader redesign. No Pencil artifact was consulted.

## History follow-up

Replace History’s fixed split pane with an adaptive grid of compact Trace run cards. Expand timing, scope, log, and run actions inline when a card is opened. This uses the window width for the run list and avoids reserving most of the screen for a single selected run. Preserve local history data and existing actions.
