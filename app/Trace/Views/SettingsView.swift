import SwiftUI

/// S14 Settings — Setup return, appearance, privacy. No budget fields.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var staged = false

    private var store: TraceStore { model.store }

    var body: some View {
        Form {
            Section("Agents & skills") {
                Picker("App run agent", selection: Binding(
                    get: { AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor },
                    set: { store.settings.preferredAgent = $0.rawValue; staged = true }
                )) {
                    ForEach(AgentKind.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Hygienic setup", isOn: Binding(
                    get: { store.skillsOptIn.hygienicSetup },
                    set: { store.skillsOptIn.hygienicSetup = $0; staged = true }
                ))
                Toggle("Session-end cleanup", isOn: Binding(
                    get: { store.skillsOptIn.sessionEnd },
                    set: { store.skillsOptIn.sessionEnd = $0; staged = true }
                ))
                Toggle("Memory writer", isOn: Binding(
                    get: { store.skillsOptIn.memoryWriter },
                    set: { store.skillsOptIn.memoryWriter = $0; staged = true }
                ))
                Button("Re-open Setup wizard") {
                    model.setupDraft = SetupDraft.from(store: store)
                    model.destination = .setup
                }
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

            Section("Menu bar & notifications") {
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
                        store.skillsOptIn.save()
                        try? store.database.saveSettings(store.settings)
                        model.background.restart()
                        staged = false
                        store.refresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .background(TraceColor.canvas)
    }
}
