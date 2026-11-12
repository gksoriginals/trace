import SwiftUI
import AppKit

/// S7–S9 Run — Reviewing → Actions → Execute. Per-project or all permitted projects.
struct RunView: View {
    @ObservedObject var model: AppModel
    let scope: AppModel.RunScope

    @State private var agent: AgentKind = .cursor
    @State private var useAgent = true
    @State private var freeBefore: Int64?
    @State private var freeAfter: Int64?

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }
    private var conductor: RunConductor { model.conductor }

    private var projects: [ProjectIndexRow] {
        switch scope {
        case .project(let p): return [p]
        case .allPermitted: return store.projects
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TraceSpace.xl) {
                    header
                    scopeBanner
                    stageRail
                    switch conductor.stage {
                    case .reviewing: reviewingBody
                    case .actions: actionsList
                    case .execute, .done: ResultPanel(model: model, freeBefore: freeBefore, freeAfter: freeAfter)
                    }
                    Text("Usage: \(conductor.usage.display) · session \(supervisor.usage.display)")
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.textSecondary)
                }
                .padding(TraceSpace.xxl)
                .frame(maxWidth: 880, alignment: .leading)
            }
            if conductor.stage == .actions {
                executeFooter
            }
        }
        .background(TraceColor.canvas)
        .onAppear {
            agent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
            freeBefore = volumeFreeBytes()
            if conductor.stage == .reviewing && conductor.cards.isEmpty {
                Task { await startReview() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            TraceScreenHeader(title: "Run", subtitle: scope.title)
            Spacer()
            AgentBadge(kind: agent, compact: true)
            Picker("Agent", selection: $agent) {
                ForEach(AgentKind.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 120)
            .accessibilityLabel("Coding agent")
            Button("Close") { model.destination = .home }
                .buttonStyle(.bordered)
        }
    }

    private var scopeBanner: some View {
        Text(scopeBannerText)
            .font(TraceType.meta)
            .foregroundStyle(TraceColor.textSecondary)
            .traceCard(elevated: true)
    }

    private var scopeBannerText: String {
        switch scope {
        case .project:
            return "Project Run: Reviewing → Actions → Execute for this project only."
        case .allPermitted:
            return "All permitted projects (\(projects.count)): same stages across every indexed Trace project under your selected roots. Never whole-disk."
        }
    }

    private var stageRail: some View {
        HStack(spacing: 0) {
            stageChip("Reviewing", active: conductor.stage == .reviewing, done: conductor.stage != .reviewing)
            connector
            stageChip("Actions", active: conductor.stage == .actions, done: conductor.stage == .execute || conductor.stage == .done)
            connector
            stageChip("Execute", active: conductor.stage == .execute || conductor.stage == .done, done: false)
        }
        .traceCard(elevated: true)
    }

    private var connector: some View {
        Rectangle()
            .fill(TraceColor.line.opacity(0.4))
            .frame(height: 1)
            .frame(maxWidth: 48)
    }

    private func stageChip(_ title: String, active: Bool, done: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : (active ? "circle.fill" : "circle"))
                .foregroundStyle(active || done ? TraceColor.brand : TraceColor.textSecondary)
            Text(title)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? TraceColor.textPrimary : TraceColor.textSecondary)
        }
        .padding(.horizontal, 8)
    }

    private var reviewingBody: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            TraceSectionLabel(title: "Reviewing")
            Toggle("Use coding agent (composed skills)", isOn: $useAgent)
                .font(TraceType.body)
            ForEach(conductor.milestones, id: \.self) { milestone in
                Label(milestone, systemImage: "checkmark")
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            if supervisor.isBusy {
                ProgressView().controlSize(.small)
                Text(supervisor.log.suffix(8).joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                if supervisor.pendingPermission != nil {
                    HStack {
                        Button("Allow once") { Task { await supervisor.replyToPermission(allow: true) } }
                        Button("Reject") { Task { await supervisor.replyToPermission(allow: false) } }
                    }
                }
                Button {
                    Task { await supervisor.cancel() }
                } label: {
                    Label("Stop", systemImage: TraceSymbol.stop)
                }
            } else {
                Button("Start Reviewing") { Task { await startReview() } }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .traceCard()
    }

    private var actionsList: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            TraceSectionLabel(title: "Actions")
            Text("Select action cards. Shared, unknown, and protected stay unselected. Selection is the consent — no second sheet.")
                .font(TraceType.body)
                .foregroundStyle(TraceColor.textSecondary)

            if conductor.cards.isEmpty {
                Text("No conservative proposals from memory. Re-run Reviewing or Ask Trace for context.")
                    .font(TraceType.body)
                    .foregroundStyle(TraceColor.textSecondary)
                    .traceCard(elevated: true)
            }

            ForEach(conductor.cards) { card in
                ActionCardRow(card: card) {
                    conductor.toggle(id: card.id)
                }
            }
        }
    }

    private var executeFooter: some View {
        let selected = conductor.cards.filter(\.selected)
        let bytes = selected.compactMap(\.bytes).reduce(0, +)
        return VStack(spacing: 0) {
            Divider().overlay(TraceColor.line.opacity(0.35))
            HStack(alignment: .center, spacing: TraceSpace.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.isEmpty
                          ? "Nothing selected"
                          : "Move \(selected.count) \(selected.count == 1 ? "item" : "items") to Trash")
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                    Text(bytes > 0
                          ? "\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)) selected · reversible via Trash"
                          : "Exact selection is consent. Protected cards stay locked.")
                        .font(TraceType.meta)
                        .foregroundStyle(TraceColor.textSecondary)
                }
                Spacer()
                Button("Back to Reviewing") {
                    conductor.stage = .reviewing
                    conductor.cards = []
                }
                .buttonStyle(.bordered)
                Button {
                    freeBefore = volumeFreeBytes()
                    conductor.execute(store: store)
                    freeAfter = volumeFreeBytes()
                    if store.settings.freedSound, conductor.results.contains(where: { $0.outcome == .moved }) {
                        NSSound(named: "Glass")?.play()
                    }
                    model.destination = .result
                } label: {
                    Label("Move \(selected.count) to Trash", systemImage: TraceSymbol.trash)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)
                .help("Single execution consent for the exact selection")
            }
            .padding(.horizontal, TraceSpace.xxl)
            .padding(.vertical, TraceSpace.lg)
            .background(TraceColor.surface)
        }
    }

    private func startReview() async {
        if useAgent {
            let payload = SkillComposer.reviewingPayload(projects: projects, store: store)
            let prompt = SkillComposer.compose(payload)
            let root = projects.first.map { store.projectRoot(for: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.path
            conductor.milestones = ["Composing skills for Reviewing (\(projects.count) project(s))…"]
            await supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
            conductor.usage = supervisor.usage
            conductor.buildLocalOnly(store: store, projects: projects, agent: agent)
            conductor.milestones.append("Agent finished: \(supervisor.status)")
        } else {
            conductor.buildLocalOnly(store: store, projects: projects, agent: agent)
        }
    }

    private func volumeFreeBytes() -> Int64? {
        guard let first = projects.first else { return nil }
        let root = store.projectRoot(for: first)
        let values = try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}

private struct ActionCardRow: View {
    let card: ActionCard
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: TraceSpace.md) {
            Toggle("Select \(card.title)", isOn: Binding(
                get: { card.selected },
                set: { _ in onToggle() }
            ))
            .disabled(card.safety == .protected)
            .labelsHidden()
            .frame(width: TraceSpace.hit, height: TraceSpace.hit)
            .accessibilityHint(card.safety == .protected ? "Protected — cannot select" : "Toggles selection only")

            CategoryLeadingMark(category: category(for: card))

            VStack(alignment: .leading, spacing: TraceSpace.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.title)
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                    Spacer()
                    SafetyBadge(state: card.safety)
                }
                Text(card.summary)
                    .font(TraceType.body)
                    .foregroundStyle(TraceColor.textSecondary)
                ForEach(card.paths.prefix(3), id: \.self) { path in
                    PathLabel(path: path)
                }
                HStack(spacing: TraceSpace.sm) {
                    Text(card.projectId)
                        .font(TraceType.path)
                        .foregroundStyle(TraceColor.textSecondary)
                    OriginBadge(origin: .app)
                    if let bytes = card.bytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                            .font(TraceType.path)
                            .foregroundStyle(TraceColor.freed)
                            .monospacedDigit()
                    }
                    if card.reversible {
                        Label("Trash-reversible", systemImage: TraceSymbol.trash)
                            .font(TraceType.caption)
                            .foregroundStyle(TraceColor.textSecondary)
                    }
                }
            }
        }
        .traceCard(selected: card.selected)
    }

    private func category(for card: ActionCard) -> StorageCategory {
        let lower = (card.title + card.summary).lowercased()
        if lower.contains("cache") { return .caches }
        if lower.contains("build") || lower.contains("dist") { return .builds }
        if lower.contains("worktree") { return .worktrees }
        if lower.contains("container") || lower.contains("docker") { return .containers }
        if lower.contains("model") { return .models }
        return .data
    }
}

struct ResultPanel: View {
    @ObservedObject var model: AppModel
    var freeBefore: Int64?
    var freeAfter: Int64?

    private var conductor: RunConductor { model.conductor }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Result")
                .font(.system(size: 18, weight: .semibold))

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    metric("Selected", "\(conductor.cards.filter(\.selected).count) cards")
                    metric("Moved", "\(conductor.results.filter { $0.outcome == .moved }.count)")
                    metric("Skipped / blocked", "\(conductor.results.filter { $0.outcome != .moved }.count)")
                }
                GridRow {
                    metric("Measured free Δ", deltaLabel)
                    metric("Before", bytes(freeBefore))
                    metric("After", bytes(freeAfter))
                }
            }
            .traceCard(elevated: true)

            ForEach(Array(conductor.results.enumerated()), id: \.offset) { _, result in
                HStack {
                    Image(systemName: result.outcome == .moved ? TraceSymbol.safe : TraceSymbol.review)
                        .foregroundStyle(result.outcome == .moved ? TraceColor.safe : TraceColor.review)
                    VStack(alignment: .leading) {
                        Text(result.path).font(.caption.monospaced())
                        Text("\(result.outcome.rawValue)\(result.reason.map { " · \($0)" } ?? "")")
                            .font(.caption2)
                            .foregroundStyle(TraceColor.textSecondary)
                    }
                }
            }

            HStack {
                Button {
                    model.destination = .recovery
                } label: {
                    Label("Undo via Trash", systemImage: TraceSymbol.undo)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .disabled(!conductor.results.contains(where: { $0.outcome == .moved }))

                Button("Ask project") {
                    model.openAsk(projectId: conductor.cards.first?.projectId, itemId: nil)
                }
                Button("Done") { model.destination = .home }
            }

            Text("Trash ≠ free bytes. Measured delta can lag or be unavailable.")
                .font(.caption)
                .foregroundStyle(TraceColor.textSecondary)
        }
        .traceCard()
    }

    private var deltaLabel: String {
        guard let before = freeBefore, let after = freeAfter else { return "unavailable" }
        let delta = after - before
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(ByteCountFormatter.string(fromByteCount: delta, countStyle: .file))"
    }

    private func bytes(_ value: Int64?) -> String {
        guard let value else { return "unavailable" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(TraceColor.textSecondary)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(TraceColor.freed)
        }
    }
}

struct ResultView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            ResultPanel(model: model, freeBefore: nil, freeAfter: nil)
                .padding(32)
                .frame(maxWidth: 880, alignment: .leading)
        }
        .background(TraceColor.canvas)
    }
}
