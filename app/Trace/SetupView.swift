import SwiftUI

/// Compact Setup: agents & skills → note on projects → save. No Execute. No budgets.
struct SetupView: View {
    var isOnboarding: Bool = false
    @EnvironmentObject private var store: TraceStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var installNote = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isOnboarding ? "Welcome to Trace" : "Setup")
                .font(.system(size: 20, weight: .semibold))
            Text("Native macOS app for storage hygiene. Skills do everyday work inside Cursor and Codex; this app shows outcomes.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TabView(selection: $step) {
                agentsStep.tag(0)
                projectsStep.tag(1)
                saveStep.tag(2)
            }
            #if os(macOS)
            .tabViewStyle(.automatic)
            #endif

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < 2 {
                    Button("Continue") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceTheme.brand(scheme))
                } else {
                    Button(isOnboarding ? "Save & open Home" : "Save") {
                        store.markSetupComplete()
                        if !isOnboarding { dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceTheme.brand(scheme))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TraceTheme.canvas(scheme))
    }

    private var agentsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agents & skills")
                .font(.system(size: 15, weight: .semibold))
            Text("Cursor and Codex first. Install is whole-agent by default.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Toggle("Memory writer", isOn: $store.skillsOptIn.memoryWriter)
            Toggle("Session-end cleanup", isOn: $store.skillsOptIn.sessionEnd)
            Toggle("Hygienic setup", isOn: $store.skillsOptIn.hygienicSetup)
            Text("Run `./skills/install.sh` from the repo to copy skills into ~/.agents/skills and ~/.cursor/skills. Trace does not read credential files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects & scope")
                .font(.system(size: 15, weight: .semibold))
            Text("Skills maintain ~/.trace/index.json. Home reads that index. Select project roots when you install with `--project`.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Index: \(store.indexURL.path)")
                .font(.system(size: 12, design: .monospaced))
            Text("\(store.projects.count) project(s) visible")
                .font(.callout)
        }
        .padding(.top, 8)
    }

    private var saveStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save")
                .font(.system(size: 15, weight: .semibold))
            Text("Saving opens Home. It does not authorize Execute. Run/cleanup execution is M2.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if !installNote.isEmpty {
                Text(installNote).font(.caption)
            }
        }
        .padding(.top, 8)
    }
}
