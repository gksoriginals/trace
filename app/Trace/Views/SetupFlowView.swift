import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Setup S1–S4 per design.md. Save installs skills; never grants Execute.
struct SetupFlowView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            stepIndicator
            ScrollView {
                Group {
                    switch step {
                    case 0: agentsStep
                    case 1: projectsStep
                    case 2: guardrailsStep
                    default: saveStep
                    }
                }
                .padding(24)
            }
            footer
        }
        .background(TraceTheme.canvas(scheme))
        .onAppear { store.refreshAgents() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.preferences.hasCompletedSetup ? "Setup" : "Welcome to Trace")
                .font(.system(size: 22, weight: .semibold))
            Text("Native macOS app. Skills do everyday hygiene in Cursor/Codex; this app installs them and reviews local outcomes.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding([.horizontal, .top], 24)
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(["Agents & skills", "Projects", "Guardrails", "Save"].enumerated()), id: \.offset) { idx, title in
                Text(title)
                    .font(.caption.weight(step == idx ? .semibold : .regular))
                    .foregroundStyle(step == idx ? TraceTheme.brand(scheme) : .secondary)
                if idx < 3 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var agentsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agents & skills")
                .font(.system(size: 15, weight: .semibold))
            ForEach(store.agents) { agent in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.displayName).font(.system(size: 13, weight: .medium))
                        Text(statusLine(agent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(agent.ready.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(agent.ready == .ready ? TraceTheme.safe(scheme) : .secondary)
                }
                .padding(12)
                .background(TraceTheme.surface(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button("Re-detect") { store.refreshAgents() }

            Toggle("Memory writer", isOn: $store.preferences.skills.memoryWriter)
            Toggle("Session-end cleanup", isOn: $store.preferences.skills.sessionEnd)
            Toggle("Hygienic setup", isOn: $store.preferences.skills.hygienicSetup)
            Toggle("Decide later (with other skills)", isOn: $store.preferences.skills.decideLater)

            Text("Install is whole-agent by default. Opt out per project on the next step by omitting it from roots / AGENTS.md line.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Path to repo skills/ folder", text: $store.skillsRootPath)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { pickSkillsRoot() }
            }
        }
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Projects & scope")
                .font(.system(size: 15, weight: .semibold))
            Text("Select project roots. Categories mean inspect/manage, not deletion permission. Shared stores never preselect as actions.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(store.preferences.projectRoots, id: \.self) { root in
                HStack {
                    Text(root).font(.system(size: 12, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Remove") {
                        store.preferences.projectRoots.removeAll { $0 == root }
                    }
                }
            }
            Button("Add project folder…") { pickProjectRoot() }

            Text("Categories")
                .font(.system(size: 13, weight: .medium))
            Toggle("Caches", isOn: $store.preferences.categories.caches)
            Toggle("Builds & environments", isOn: $store.preferences.categories.builds)
            Toggle("Worktrees", isOn: $store.preferences.categories.worktrees)
            Toggle("Containers", isOn: $store.preferences.categories.containers)
            Toggle("Models", isOn: $store.preferences.categories.models)
            Toggle("Project data", isOn: $store.preferences.categories.projectData)
        }
    }

    private var guardrailsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guardrails")
                .font(.system(size: 15, weight: .semibold))

            Picker("Coding agent for a later app Run", selection: $store.preferences.preferredAgent) {
                Text("Cursor").tag("cursor")
                Text("Codex").tag("codex")
            }
            .pickerStyle(.radioGroup)

            Text("Never-touch folders (one path per line)")
                .font(.caption)
            TextEditor(text: Binding(
                get: { store.preferences.neverTouch.joined(separator: "\n") },
                set: { store.preferences.neverTouch = $0.split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 80)
            .border(Color.primary.opacity(0.1))

            Toggle("Menu bar extra", isOn: $store.preferences.menuBarEnabled)
            Toggle("Decide-later notifications (off by default)", isOn: $store.preferences.decideLaterNotifications)
            Toggle("Optional review schedule (off; only while app runs)", isOn: $store.preferences.scheduleEnabled)
            Toggle("Freed sound", isOn: $store.preferences.freedSound)

            Text("No token or time budget. Trace does not auto-empty Trash. FDA is not requested here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var saveStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save & first run")
                .font(.system(size: 15, weight: .semibold))
            Text("This saves configuration and installs opted-in skills into host skill folders. It never authorizes Execute.")
                .font(.callout)
                .foregroundStyle(.secondary)

            labelled("Skills root", store.skillsRootPath.isEmpty ? "(not set)" : store.skillsRootPath)
            labelled("Projects", store.preferences.projectRoots.isEmpty ? "(none — skills still install whole-agent)" : store.preferences.projectRoots.joined(separator: "\n"))
            labelled("Preferred agent", store.preferences.preferredAgent)
            labelled("Provider boundary", "Invoking a coding agent may send permitted context to its provider. Local memory stays on disk.")

            if !store.installLog.isEmpty {
                Text(store.installLog)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(TraceTheme.elevated(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
            }
            if store.preferences.hasCompletedSetup {
                Button("Cancel") { store.route = .home }
            }
            Spacer()
            if step < 3 {
                Button("Continue") {
                    store.persist()
                    step += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceTheme.brand(scheme))
            } else {
                Button("Save without running") {
                    store.saveSetup(runFirstReviewNote: false)
                }
                Button("Save & first run") {
                    store.saveSetup(runFirstReviewNote: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceTheme.brand(scheme))
                .disabled(store.skillsRootPath.isEmpty)
            }
        }
        .padding(24)
    }

    private func statusLine(_ agent: AgentStatus) -> String {
        switch agent.ready {
        case .ready:
            return [agent.binary, agent.version].compactMap { $0 }.joined(separator: " · ")
        case .absent:
            return "CLI not on PATH"
        case .unsupported:
            return "Later adapter — not M1"
        default:
            return agent.ready.rawValue
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, design: .monospaced))
        }
    }

    private func pickSkillsRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the Trace repo skills/ directory"
        if panel.runModal() == .OK, let url = panel.url {
            store.skillsRootPath = url.path
        }
    }

    private func pickProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project root for Trace"
        if panel.runModal() == .OK, let url = panel.url {
            if !store.preferences.projectRoots.contains(url.path) {
                store.preferences.projectRoots.append(url.path)
            }
        }
    }
}
