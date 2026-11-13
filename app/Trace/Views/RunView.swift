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
                VStack(alignment: .leading, spacing: TraceSpace.lg) {
                    header
                    stageRail
                    if supervisor.isFailed {
                        TraceStatusBanner(
                            kind: .error,
                            title: "Reviewing failed — \(agent.title)",
                            detail: supervisor.lastMessage ?? "Unknown error",
                            primaryTitle: "Retry Reviewing",
                            primaryAction: { Task { await startReview() } },
                            secondaryTitle: "Dismiss",
                            secondaryAction: { supervisor.dismissStatus() }
                        )
                    } else if supervisor.isBusy {
                        TraceStatusBanner(
                            kind: .working,
                            title: "Reviewing with \(agent.title)…",
                            detail: supervisor.lastMessage,
                            primaryTitle: "Stop",
                            primaryAction: { Task { await supervisor.cancel() } }
                        )
                    }
                    switch conductor.stage {
                    case .reviewing: reviewingBody
                    case .actions: actionsList
                    case .execute, .done: ResultPanel(model: model, freeBefore: freeBefore, freeAfter: freeAfter)
                    }
                }
                .tracePageColumn(maxWidth: .infinity)
            }
            if conductor.stage == .actions {
                executeFooter
            }
        }
        .background(TraceColor.canvas)
        .task {
            agent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
            freeBefore = volumeFreeBytes()
            if conductor.stage == .reviewing && conductor.cards.isEmpty && !supervisor.isBusy {
                await startReview()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: TraceSpace.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Run")
                    .font(TraceType.screen)
                    .foregroundStyle(TraceColor.textPrimary)
                Text(scopeSubtitle)
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Spacer()
            Picker("Agent", selection: $agent) {
                ForEach(AgentKind.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 110)
            .accessibilityLabel("Coding agent")
            Button("Close") {
                supervisor.dismissStatus()
                model.destination = .home
            }
            .buttonStyle(.bordered)
        }
    }

    private var scopeSubtitle: String {
        switch scope {
        case .project(let p):
            return "\(p.displayName) · Reviewing → Actions → Execute"
        case .allPermitted:
            return "\(projects.count) projects · never whole-disk"
        }
    }

    private var stageRail: some View {
        HStack(spacing: TraceSpace.md) {
            stageChip("1 Reviewing", active: conductor.stage == .reviewing, done: conductor.stage != .reviewing)
            stageChip("2 Actions", active: conductor.stage == .actions, done: conductor.stage == .execute || conductor.stage == .done)
            stageChip("3 Execute", active: conductor.stage == .execute || conductor.stage == .done, done: false)
            Spacer(minLength: 0)
        }
        .font(TraceType.meta)
    }

    private func stageChip(_ title: String, active: Bool, done: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: active ? .semibold : .regular))
            .foregroundStyle(active || done ? TraceColor.brand : TraceColor.textSecondary)
    }

    private var reviewingBody: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            Toggle("Use coding agent", isOn: $useAgent)
                .font(TraceType.body)
            if !conductor.milestones.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(conductor.milestones.suffix(6), id: \.self) { milestone in
                        Text("· \(milestone)")
                            .font(TraceType.meta)
                            .foregroundStyle(TraceColor.textSecondary)
                    }
                }
            }
            if !supervisor.isBusy {
                Button {
                    Task { await startReview() }
                } label: {
                    Label(supervisor.isFailed ? "Retry Reviewing" : "Start Reviewing", systemImage: TraceSymbol.run)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var actionsList: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            Text("Select cards to Trash. Selection is consent.")
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)

            if conductor.cards.isEmpty {
                TraceStatusBanner(
                    kind: .info,
                    title: "No action cards yet",
                    detail: "Memory had nothing conservative to propose. Run Reviewing again after skills write events.",
                    primaryTitle: "Start Reviewing",
                    primaryAction: { Task { await startReview() } }
                )
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
                    Task { await startReview() }
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
        guard !projects.isEmpty else {
            conductor.stage = .reviewing
            conductor.milestones = ["No projects in scope. Add a root in Setup or Settings."]
            return
        }
        conductor.stage = .reviewing
        conductor.cards = []
        conductor.results = []
        conductor.usage = .unavailable

        if useAgent {
            let payload = SkillComposer.reviewingPayload(projects: projects, store: store)
            let prompt = SkillComposer.compose(payload)
            let root = projects.first.map { store.projectRoot(for: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.path
            conductor.milestones = [
                "Starting Reviewing for \(projects.count) project(s)…",
                "Opening \(agent.title) session…",
            ]
            await supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
            conductor.usage = supervisor.usage
            store.refresh()

            // Stay on Reviewing when the agent never ran — do not fake an Actions pass.
            if supervisor.status == "error" || supervisor.status == "cancelled" {
                conductor.milestones.append("Agent session \(supervisor.status). Fix the session, then Start Reviewing again.")
                return
            }
            conductor.milestones.append("Agent finished: \(supervisor.status)")
            conductor.applyCards(from: projects, store: store, agent: agent, advanceToActions: true)
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
                .tracePageColumn(maxWidth: 880)
        }
        .background(TraceColor.canvas)
    }
}
