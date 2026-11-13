import SwiftUI

/// S14 Settings — Setup return, appearance, privacy. No budget fields.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var staged = false
    @State private var detecting = false
    @State private var probeMessage = ""
    @State private var cursorStatus: AgentAuthStatus = .unknown
    @State private var codexStatus: AgentAuthStatus = .unknown
    @State private var cursorVersion: String?
    @State private var codexVersion: String?

    private var store: TraceStore { model.store }

    private var enabledAgents: [AgentKind] {
        let saved = store.settings.enabledAgents.compactMap(AgentKind.init(rawValue:))
        let set = Set(saved.isEmpty ? AgentKind.allCases : saved)
        return set.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        Form {
            Section {
                Text("Whole-agent install with per-project opt-out. Opt-in skills are per agent.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)

                ForEach(enabledAgents) { kind in
                    agentSkillsBlock(kind)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add another agent")
                            .font(.system(size: 13, weight: .medium))
                        Text(probeMessage.isEmpty
                             ? "Detect another CLI. Skills opt-in when that agent is added."
                             : probeMessage)
                            .font(.caption)
                            .foregroundStyle(TraceColor.textSecondary)
                    }
                    Spacer()
                    Button {
                        Task { await addAgent() }
                    } label: {
                        Label(detecting ? "Detecting…" : "Add agent", systemImage: "plus")
                    }
                    .disabled(detecting)
                }

                Picker("App run agent", selection: Binding(
                    get: { AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor },
                    set: { store.settings.preferredAgent = $0.rawValue; staged = true }
                )) {
                    ForEach(enabledAgents) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Agents & skills")
            }

            Section("Projects & scope") {
                ForEach(store.settings.selectedRoots, id: \.self) { root in
                    HStack {
                        Text(root).font(.caption.monospaced())
                        Spacer()
                        Toggle("Opt out", isOn: Binding(
                            get: { store.settings.optedOutProjects.contains(root) },
                            set: { on in
                                if on { store.settings.optedOutProjects.append(root) }
                                else { store.settings.optedOutProjects.removeAll { $0 == root } }
                                staged = true
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
                Text("Categories: \(store.settings.categories.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }

            Section("Guardrails & retention") {
                TextEditor(text: Binding(
                    get: { store.settings.neverTouch.joined(separator: "\n") },
                    set: {
                        store.settings.neverTouch = $0.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                        staged = true
                    }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80)
                Stepper(
                    "Memory retention: \(store.settings.memoryRetentionDays) days",
                    value: Binding(
                        get: { store.settings.memoryRetentionDays },
                        set: { store.settings.memoryRetentionDays = $0; staged = true }
                    ),
                    in: 7...365
                )
            }

            Section("Notifications") {
                Toggle("Decide-later notifications", isOn: Binding(
                    get: { store.settings.notificationsDecideLater },
                    set: { store.settings.notificationsDecideLater = $0; staged = true }
                ))
                Toggle("Background review while app running", isOn: Binding(
                    get: { store.settings.backgroundReviewEnabled },
                    set: { store.settings.backgroundReviewEnabled = $0; staged = true }
                ))
                Toggle("Freed sound", isOn: Binding(
                    get: { store.settings.freedSound },
                    set: { store.settings.freedSound = $0; staged = true }
                ))
            }

            Section("Appearance") {
                Picker("Appearance", selection: Binding(
                    get: { store.settings.appearance },
                    set: { store.settings.appearance = $0 }
                )) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Text("Appearance applies immediately. Config changes need Apply.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }

            Section("Privacy") {
                Text("Trace never scrapes credential files. Invoking Cursor or Codex may send minimized scope to that provider. Local memory stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }

            if staged {
                Section {
                    Button("Apply") {
                        applyStaged()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .background(TraceColor.canvas)
        .task { await refreshProbe(enableNew: false) }
    }

    @ViewBuilder
    private func agentSkillsBlock(_ kind: AgentKind) -> some View {
        let status = kind == .cursor ? cursorStatus : codexStatus
        let version = kind == .cursor ? cursorVersion : codexVersion
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kind.title).fontWeight(.semibold)
                Spacer()
                Text(statusLabel(status))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor(status))
            }
            Text(version.map { "CLI \($0) · \(kind == .cursor ? "ACP" : "app-server")" } ?? "\(kind == .cursor ? "ACP" : "app-server")")
                .font(.caption)
                .foregroundStyle(TraceColor.textSecondary)
            Text("Opt-in skills")
                .font(.caption.weight(.medium))
                .foregroundStyle(TraceColor.textSecondary)
            Toggle("Hygienic setup", isOn: skillBinding(kind, \.hygienicSetup))
            Toggle("Session-end cleanup", isOn: skillBinding(kind, \.sessionEnd))
            Toggle("Memory writer", isOn: skillBinding(kind, \.memoryWriter))
        }
        .padding(.vertical, 4)
    }

    private func skillBinding(_ kind: AgentKind, _ keyPath: WritableKeyPath<AgentSkillsOptIn, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.skillsOptIn[kind][keyPath: keyPath] },
            set: { newValue in
                var opt = store.skillsOptIn
                var agent = opt[kind]
                agent[keyPath: keyPath] = newValue
                opt[kind] = agent
                store.skillsOptIn = opt
                staged = true
            }
        )
    }

    private func statusLabel(_ status: AgentAuthStatus) -> String {
        switch status {
        case .ready: return "App session ready"
        case .unknown: return "Sign-in unknown"
        case .unsupported: return "CLI not found"
        case .termsUnmet: return "Terms unmet"
        }
    }

    private func statusColor(_ status: AgentAuthStatus) -> Color {
        switch status {
        case .ready: return TraceColor.safe
        case .unknown: return TraceColor.review
        case .unsupported, .termsUnmet: return TraceColor.critical
        }
    }

    private func addAgent() async {
        await refreshProbe(enableNew: true)
    }

    private func refreshProbe(enableNew: Bool) async {
        detecting = true
        defer { detecting = false }
        let result = await AgentProbe.probeAll()
        cursorVersion = result.cursor.0
        cursorStatus = result.cursor.1
        codexVersion = result.codex.0
        codexStatus = result.codex.1

        guard enableNew else { return }

        var enabled = Set(store.settings.enabledAgents.compactMap(AgentKind.init(rawValue:)))
        if enabled.isEmpty { enabled = Set(AgentKind.allCases) }
        var added: [String] = []
        if result.cursor.1 != .unsupported, enabled.insert(.cursor).inserted {
            added.append("Cursor")
        }
        if result.codex.1 != .unsupported, enabled.insert(.codex).inserted {
            added.append("Codex")
        }
        // Keep agents that are already enabled even if temporarily unsupported.
        store.settings.enabledAgents = enabled.map(\.rawValue).sorted()
        if added.isEmpty {
            let found = [result.cursor.1 != .unsupported ? "Cursor" : nil, result.codex.1 != .unsupported ? "Codex" : nil]
                .compactMap { $0 }
            probeMessage = found.isEmpty
                ? "No new CLI found. Install Cursor or Codex, then try again."
                : "Already added: \(found.joined(separator: ", "))."
        } else {
            probeMessage = "Added \(added.joined(separator: ", ")). Opt in skills above, then Apply."
            staged = true
        }
    }

    private func applyStaged() {
        store.skillsOptIn.save()
        try? store.database.saveSettings(store.settings)
        do {
            let project = store.settings.optedOutProjects.contains(store.settings.selectedRoots.first ?? "")
                ? nil
                : store.settings.selectedRoots.first
            let enabled = store.settings.enabledAgents.compactMap(AgentKind.init(rawValue:))
            _ = try SkillInstaller.install(optIn: store.skillsOptIn, enabledAgents: enabled, projectPath: project)
        } catch {
            probeMessage = error.localizedDescription
        }
        model.background.restart()
        staged = false
        store.refresh()
    }
}
