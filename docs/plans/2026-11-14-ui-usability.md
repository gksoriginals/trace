# UI density and usability

Intent: make the existing local overview useful at ordinary desktop sizes, improve navigation discoverability, and reduce unnecessary gutters without filling sparse data with decoration. The running app and source are the reference; the Pencil design is explicitly excluded.

Approach: replace the detached icon rail with compact labeled top navigation; keep project cards fluid, place Add folder in the heading, surface queue status and recent local runs; widen project detail; label guardrail input and keep Settings Apply visible. Retain native controls, theme tokens, macOS 14, local-only Home, explicit paid work, and all cleanup consent/fingerprint safeguards. Reject enlarged decorative tiles and invented storage metrics.

Contracts: presentation only. No changes to session protocols, memory formats, selection, cleanup, or skill installation. No existing Taste Pack.

Verification: baseline and final `xcodebuild -project app/Trace.xcodeproj -scheme Trace -configuration Release -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- build`; computer-use navigation of Home, project, queue, History, Settings, and Ask. Existing Python safety tests are acceptance/contract tests for unchanged boundaries; no implementation-coupled UI tests exist and no test expectations will change. Run `python3 -m unittest discover -s skills/shared/tests` as regression coverage. No model eval claim or paid agent invocation.

Baseline: Home has capped 220–320 pt tiles, a full Add tile, icon-only navigation, and a 760 pt project-detail cap. AX navigation works. Computer-use screenshots currently show only a distorted small window thumbnail, so visual verification is limited pending a fresh build launch.

## Owner correction and final scope

The owner preferred the original UI. Restore the icon rail, Add tile, original Home hierarchy and project actions. Final changes are fluid card widths, wider and tighter project details, rendered summary emphasis, removal of redundant Settings outer padding, labeled protected paths, and a sticky Apply row only for staged changes. Reject the attempted redesign.

Computer-use navigation intermittently crashes inside macOS SwiftUI accessibility label resolution (EXC_BAD_ACCESS / recursive accessibility stack); this is a concrete verification limitation, not evidence of successful navigation. Recheck the restored UI.

## Final checks

- Pass: Release build after restoring original design.
- Pass: six existing Python safety tests; no test changes.
- Pass: source diff confirms original Chrome unchanged; original Home sections/actions retained. History styling changes are present in the rebuilt view.
- Pass: computer-use AX confirms restored Home opened with project cards and original rail.
- Unverified: complete final visual, resized/light appearance, project/History interaction and staged Apply validation; accessibility clicks trigger a recursive SwiftUI accessibility crash. No paid runs or cleanup performed.
- Updated build is open from the existing project build directory; /Applications copy was not replaced.

## History follow-up

Owner request: reduce excess spacing in History and use the same card UI as other surfaces. Keep the existing master-detail interaction and local history contract; style each run index item as a compact Trace card and trim pane/detail padding. Avoid increasing minimum row height or changing navigation/actions. Verify at populated and empty states from source/available runtime; do not invoke an agent.


History follow-up build and safety tests: Release build succeeded; six existing Python tests passed. History rendering in the running app remains unverified because its navigation click triggers the same computer-use accessibility crash.


## History correction and installed verification

The owner reported that History still looked unchanged. The previous binary was installed, but macOS reused the old running process. History is now an adaptive grid of Trace cards, with full details expanding inline. Replaced the installed app, terminated the old process, and launched a new process from `/Applications/Trace.app`. Accessibility tree now shows the History collection with the run card and “Show details”; the screenshot service returned a distorted thumbnail, so pixel-level visual inspection remains limited. Release build succeeded.
