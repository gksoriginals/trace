import SwiftUI
import AppKit

/// Full PRD/design Setup S1–S4.
struct SetupView: View {
    @ObservedObject var model: AppModel
    @State private var detecting = false

    private var draft: Binding<SetupDraft> { $model.setupDraft }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraceSpace.xl) {
                header
                stepRail
                stepBody
                navButtons
            }
            .padding(TraceSpace.xxl)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .background(TraceColor.canvas)
        .task { await redetect() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: TraceSpace.md) {
            TraceMark(size: 36)
            TraceScreenHeader(
                title: "Setup",
                subtitle: "Skills do everyday hygiene inside each coding agent. Trace configures them per host, shows outcomes, and runs a deeper pass when you ask."
            )
        }
    }

    private var stepRail: some View {
        HStack(spacing: 12) {
            ForEach(Array(["Agents & skills", "Projects & scope", "Guardrails", "Save & first run"].enumerated()), id: \.offset) { i, title in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(i <= draft.wrappedValue.step ? TraceColor.brand : TraceColor.elevated)
                            .frame(width: 24, height: 24)
                        if i < draft.wrappedValue.step {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TraceColor.onBrand)
                        } else {
                            Text("\(i + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(i == draft.wrappedValue.step ? TraceColor.onBrand : TraceColor.textSecondary)
                        }
                    }
                    Text(title)
                        .font(.system(size: 12, weight: i == draft.wrappedValue.step ? .semibold : .regular))
                        .foregroundStyle(i == draft.wrappedValue.step ? TraceColor.textPrimary : TraceColor.textSecondary)
                }
                if i < 3 {
                    Rectangle().fill(TraceColor.line.opacity(0.4)).frame(height: 1).frame(maxWidth: 40)
                }
            }
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch draft.wrappedValue.step {
        case 0: stepAgents
        case 1: stepProjects
        case 2: stepGuardrails
        default: stepSave
        }
    }

    private var stepAgents: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agents & skills")
                .font(.system(size: 20, weight: .semibold))
            Text("Whole-agent install by default. Opt-in skills per agent — each host gets its own skills folder. A project can opt out later. No plugin, no MCP.")
                .foregroundStyle(TraceColor.textSecondary)

            let agents = draft.wrappedValue.enabledAgents.sorted { $0.rawValue < $1.rawValue }
            if agents.isEmpty {
                Text("No coding agents detected yet. Install a CLI, then Add agent.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
                    .traceCard(elevated: true)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(agents) { kind in
                        agentCard(kind)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Need another harness?")
                        .font(.system(size: 13, weight: .medium))
                    Text("Installed another CLI? Detect it here.")
                        .font(.caption)
                        .foregroundStyle(TraceColor.textSecondary)
                }
                Spacer()
                Button {
                    Task { await redetect() }
                } label: {
                    Label(detecting ? "Detecting…" : "Add agent", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .disabled(detecting)
            }
            .traceCard(elevated: true)

            if !agents.isEmpty {
                Picker("Coding agent for app runs", selection: draft.preferredAgent) {
                    ForEach(agents) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Button {
                Task { await redetect() }
            } label: {
                Label(detecting ? "Detecting…" : "Re-detect CLIs", systemImage: "arrow.clockwise")
            }
            .disabled(detecting)
        }
    }

    private func agentCard(_ kind: AgentKind) -> some View {
        let skills = Binding(
            get: { draft.wrappedValue.skillsByAgent[kind] ?? AgentSkillsOptIn() },
            set: { draft.wrappedValue.skillsByAgent[kind] = $0 }
        )
        return VStack(alignment: .leading, spacing: 10) {
            AgentBadge(kind: kind)
            statusPill(draft.wrappedValue.status(for: kind))
            Text(draft.wrappedValue.version(for: kind).map { "CLI \($0)" } ?? "Version unknown")
                .font(.caption.monospaced())
                .foregroundStyle(TraceColor.textSecondary)
            Text("Session adapter: \(kind == .cursor ? "ACP" : "app-server")")
                .font(.caption)
                .foregroundStyle(TraceColor.textSecondary)

            Text("Opt-in skills for \(kind.title)")
                .font(.caption.weight(.medium))
                .foregroundStyle(TraceColor.textSecondary)
                .padding(.top, 4)
            Toggle("Hygienic setup", isOn: skills.hygienicSetup)
            Toggle("Session-end cleanup", isOn: skills.sessionEnd)
            Toggle("Memory writer", isOn: skills.memoryWriter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .traceCard(selected: draft.wrappedValue.preferredAgent == kind)
        .onTapGesture { draft.wrappedValue.preferredAgent = kind }
    }

    private func statusPill(_ status: AgentAuthStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .ready: return ("App session ready", TraceColor.safe)
            case .unknown: return ("Sign-in unknown — use vendor login", TraceColor.review)
            case .unsupported: return ("CLI not found", TraceColor.critical)
            case .termsUnmet: return ("Terms unmet", TraceColor.critical)
            }
        }()
        return Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
    }

    private var stepProjects: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Projects & scope")
                .font(.system(size: 20, weight: .semibold))
            Text("Suggest from local Git/IDE-style folders. Discover inside selected roots only — never whole disk. Categories mean inspect, not delete.")
                .foregroundStyle(TraceColor.textSecondary)

            HStack {
                Button {
                    draft.wrappedValue.suggestedPaths = AgentProbe.suggestProjectRoots()
                } label: {
                    Label("Suggest directories", systemImage: "sparkle.magnifyingglass")
                }
                Button {
                    pickFolder()
                } label: {
                    Label("Add folder…", systemImage: "folder.badge.plus")
                }
            }

            if !draft.wrappedValue.suggestedPaths.isEmpty {
                Text("Suggestions")
                    .font(.system(size: 15, weight: .semibold))
                ForEach(draft.wrappedValue.suggestedPaths, id: \.self) { path in
                    Toggle(isOn: Binding(
                        get: { draft.wrappedValue.projectPaths.contains(path) },
                        set: { on in
                            if on { draft.wrappedValue.projectPaths.append(path) }
                            else { draft.wrappedValue.projectPaths.removeAll { $0 == path } }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(URL(fileURLWithPath: path).lastPathComponent).fontWeight(.medium)
                            Text(path).font(.caption.monospaced()).foregroundStyle(TraceColor.textSecondary)
                            Text("Evidence: local Git root").font(.caption2).foregroundStyle(TraceColor.textSecondary)
                        }
                    }
                    .traceCard()
                }
            }

            if !draft.wrappedValue.projectPaths.isEmpty {
                Text("Selected roots")
                    .font(.system(size: 15, weight: .semibold))
                ForEach(draft.wrappedValue.projectPaths, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                        Text(path).font(.caption.monospaced())
                        Spacer()
                        Toggle("Opt out of skill line", isOn: Binding(
                            get: { draft.wrappedValue.optedOutProjects.contains(path) },
                            set: { on in
                                if on { draft.wrappedValue.optedOutProjects.append(path) }
                                else { draft.wrappedValue.optedOutProjects.removeAll { $0 == path } }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        Button(role: .destructive) {
                            draft.wrappedValue.projectPaths.removeAll { $0 == path }
                        } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.plain)
                    }
                    .traceCard()
                }
            }

            Text("Categories (all on = inspect/manage)")
                .font(.system(size: 15, weight: .semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(StorageCategory.allCases) { cat in
                    let on = draft.wrappedValue.enabledCategories.contains(cat.rawValue)
                    Button {
                        if on {
                            draft.wrappedValue.enabledCategories.removeAll { $0 == cat.rawValue }
                        } else {
                            draft.wrappedValue.enabledCategories.append(cat.rawValue)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: cat.symbol)
                                .foregroundStyle(cat.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cat.title).fontWeight(.semibold).foregroundStyle(TraceColor.textPrimary)
                                Text(on ? "On" : "Off")
                                    .font(.caption)
                                    .foregroundStyle(TraceColor.textSecondary)
                                if cat == .caches {
                                    Text("Shared mark — never pre-tick actions")
                                        .font(.caption2)
                                        .foregroundStyle(TraceColor.review)
                                }
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.square.fill" : "square")
                                .foregroundStyle(on ? TraceColor.brand : TraceColor.line)
                        }
                        .traceCard(selected: on)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepGuardrails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guardrails")
                .font(.system(size: 20, weight: .semibold))
            Text("No token or time budget. Background review only while Trace is running.")
                .foregroundStyle(TraceColor.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Never-touch folders").fontWeight(.semibold)
                TextEditor(text: Binding(
                    get: { draft.wrappedValue.neverTouch.joined(separator: "\n") },
                    set: { draft.wrappedValue.neverTouch = $0.split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
            }
            .traceCard()

            let agents = draft.wrappedValue.enabledAgents.sorted { $0.rawValue < $1.rawValue }
            if !agents.isEmpty {
                Picker("App run agent", selection: draft.preferredAgent) {
                    ForEach(agents) { Text($0.title).tag($0) }
                }
            }

            Stepper("Memory retention: \(draft.wrappedValue.retentionDays) days", value: draft.retentionDays, in: 7...365)

            Toggle("Decide-later notifications (opt-in)", isOn: draft.notifyDecideLater)
            Toggle("Optional background review while app running", isOn: draft.backgroundReview)
            Toggle("Freed sound on successful Execute", isOn: draft.freedSound)

            DisclosureGroup("Advanced") {
                Text("Full Disk Access is requested only for a specific blocked surface — never as a mandatory gate. Trace never scrapes credential files. Quit ends owned work and any optional background review. There is no menu bar companion and no helper after quit.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
                    .padding(.top, 8)
            }
        }
    }

    private var stepSave: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save & first run")
                .font(.system(size: 20, weight: .semibold))
            Text("Saves config, installs opted-in skills per agent (except opted-out projects), then can start a read-only first Reviewing pass. Never Execute.")
                .foregroundStyle(TraceColor.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(draft.wrappedValue.enabledAgents.sorted { $0.rawValue < $1.rawValue }) { kind in
                    let skills = draft.wrappedValue.skillsByAgent[kind] ?? AgentSkillsOptIn()
                    summaryRow("Skills · \(kind.title)", skills.summaryLabel)
                }
                summaryRow("Agent", draft.wrappedValue.preferredAgent.title)
                summaryRow("Roots", draft.wrappedValue.projectPaths.isEmpty ? "None yet" : draft.wrappedValue.projectPaths.joined(separator: "\n"))
                summaryRow("Categories", draft.wrappedValue.enabledCategories.joined(separator: ", "))
                summaryRow("Opt-outs", draft.wrappedValue.optedOutProjects.isEmpty ? "None" : draft.wrappedValue.optedOutProjects.joined(separator: "\n"))
                summaryRow("Provider boundary", "Invoking Cursor/Codex may send minimized scope to that provider. Local memory stays on this Mac.")
            }
            .traceCard()

            if !draft.wrappedValue.lastMessage.isEmpty {
                Text(draft.wrappedValue.lastMessage)
                    .font(.caption.monospaced())
                    .foregroundStyle(TraceColor.textSecondary)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(TraceColor.textSecondary)
            Text(value).font(.system(size: 13, design: .monospaced))
        }
    }

    private var navButtons: some View {
        HStack {
            if draft.wrappedValue.step > 0 {
                Button("Back") { draft.wrappedValue.step -= 1 }
            }
            Spacer()
            if draft.wrappedValue.step < 3 {
                Button("Continue") { draft.wrappedValue.step += 1 }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Save without running") {
                    Task { await model.finishSetup(runFirstPass: false) }
                }
                Button("Save & first run") {
                    Task { await model.finishSetup(runFirstPass: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func redetect() async {
        detecting = true
        defer { detecting = false }
        let result = await AgentProbe.probeAll()
        draft.wrappedValue.applyProbe(cursor: result.cursor, codex: result.codex)
        if draft.wrappedValue.suggestedPaths.isEmpty {
            draft.wrappedValue.suggestedPaths = AgentProbe.suggestProjectRoots()
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                if !draft.wrappedValue.projectPaths.contains(url.path) {
                    draft.wrappedValue.projectPaths.append(url.path)
                }
            }
        }
    }
}
