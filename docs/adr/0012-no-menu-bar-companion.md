# ADR-0012: No menu bar companion

- **Status:** accepted
- **Date:** 2026-11-13
- **Deciders:** Gopi
- **Supersedes:** [ADR-0008](0008-full-app-vs-menubar.md) (menu bar half)

## Context

A `MenuBarExtra` companion (design S15) kept Trace in the status bar after the main window closed and hosted optional background review. That clutters the menu bar and duplicates what the dock + main window already do. Skills already run inside coding agents without Trace open.

## Decision

1. **No menu bar app / status item.** Trace is a regular macOS window app only.
2. **Lifecycle:** Quit ends owned agent work, checkpoints, and any optional background review. There is still no helper after quit and no login item.
3. **Background review** (if opted in) runs only while the Trace **app process** is running — not via a status-item keep-alive.
4. Design surface **S15 is removed**. Ask / Stop / Settings stay in the main window and the app menu.

## Consequences

Closing the last window follows normal app behavior (dock until Quit). Optional schedule copy and Settings no longer mention a menu bar companion. Firm rule “background work only while the app is running” still holds; it no longer means “while a menu bar extra is installed.”

## What would change it

Strong dogfood evidence that users need a status-item glance without opening the window — still not a reason to put cleanup or consent in the menu bar.
