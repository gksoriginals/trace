# Preserve Home's existing design when fixing density

Owner decision, 14 November 2026: spacing/usability work should preserve the right icon rail, project-card grid, and Add folder tile. A proposed top navigation, new overview sections, and extra card actions were rejected in favor of the existing UI. Do not interpret a request to reduce negative space as permission to replace this hierarchy.

First correct width constraints, redundant insets, and content spacing. Retain room below sparse records rather than manufacturing content or starting agent work. A future explicit redesign can supersede this preference; it is not a prohibition on fixing actual interaction problems.

Evidence: `docs/adr/0013-preserve-layout-fix-spacing.md`; `app/Trace/Views/Chrome.swift` (`AppChrome`); `app/Trace/Views/HomeView.swift` (`insightsLane`). Source reviewed. Final full visual/interaction verification remains incomplete because computer-use accessibility clicks triggered a SwiftUI accessibility crash; do not treat this guidance as proof that every layout state passed.

Visual behavior is unverified for the complete final flow.
