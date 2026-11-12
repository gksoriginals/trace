import SwiftUI
import AppKit

/// S7–S9 Run — Reviewing → Actions → Execute. Selection is consent.
struct RunView: View {
    @ObservedObject var model: AppModel
    let project: ProjectIndexRow

    @State private var agent: AgentKind = .cursor
    @State private var useAgent = true
    @State private var freeBefore: Int64?
    @State private var freeAfter: Int64?

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }
    private var conductor: RunConductor { model.conductor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                stageRail
                switch conductor.stage {
                case .reviewing: reviewingBody
                case .actions: actionsBody
                case .execute, .done: resultsBody
                }
                Text("Usage: \(conductor.usage.display) · session \(supervisor.usage.display)")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Run")
                    .font(.system(size: 28, weight: .semibold))
                Text(project.displayName)
                    .font(.system(size: 14))
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Spacer()
            AgentBadge(kind: agent, compact: true)
            Picker("Agent", selection: $agent) {
                ForEach(AgentKind.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 120)
            Button("Close") { model.destination = .home }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviewing")
                .font(.system(size: 18, weight: .semibold))
            Text("Composed skills propose candidates. Nothing moves until you select cards and Execute.")
                .foregroundStyle(TraceColor.textSecondary)
            Toggle("Use coding agent (composed skills)", isOn: $useAgent)
            ForEach(conductor.milestones, id: \.self) { milestone in
                Label(milestone, systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            if supervisor.isBusy {
                ProgressView()
                    .controlSize(.small)
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

    private var actionsBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.system(size: 18, weight: .semibold))
            Text("Select action cards. Shared, unknown, and protected stay unselected by default. Selection is consent — no second sheet.")
                .font(.system(size: 13))
                .foregroundStyle(TraceColor.textSecondary)

            if conductor.cards.isEmpty {
                Text("No conservative proposals from memory. Re-run Reviewing or Ask Trace for context.")
                    .foregroundStyle(TraceColor.textSecondary)
            }

            ForEach(conductor.cards) { card in
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { card.selected },
                        set: { _ in conductor.toggle(id: card.id) }
                    ))
                    .disabled(card.safety == .protected)
                    .labelsHidden()

                    categoryGlyph(for: card)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(card.title)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            SafetyBadge(state: card.safety)
                        }
                        Text(card.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(TraceColor.textSecondary)
                        Text(card.paths.joined(separator: "\n"))
                            .font(.caption2.monospaced())
                            .foregroundStyle(TraceColor.textSecondary)
                            .lineLimit(3)
                        if let bytes = card.bytes {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(TraceColor.freed)
                        }
                        HStack {
                            OriginBadge(origin: .app)
                            if card.reversible {
                                Label("Trash-reversible", systemImage: TraceSymbol.trash)
                                    .font(.caption2)
                                    .foregroundStyle(TraceColor.textSecondary)
                            }
                        }
                    }
                }
                .traceCard(selected: card.selected)
            }

            HStack {
                let selected = conductor.cards.filter(\.selected)
                Button {
                    freeBefore = volumeFreeBytes()
                    conductor.execute(store: store)
                    freeAfter = volumeFreeBytes()
                    if store.settings.freedSound, conductor.results.contains(where: { $0.outcome == .moved }) {
                        NSSound(named: "Glass")?.play()
                    }
                    model.destination = .result
                } label: {
                    Label("Execute \(selected.count) selected", systemImage: TraceSymbol.trash)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)

                Button("Back to Reviewing") {
                    conductor.stage = .reviewing
                    conductor.cards = []
                }
            }
        }
    }

    private var resultsBody: some View {
        ResultPanel(
            model: model,
            freeBefore: freeBefore,
            freeAfter: freeAfter
        )
    }

    private func categoryGlyph(for card: ActionCard) -> some View {
        let lower = card.title.lowercased() + card.summary.lowercased()
        let cat: StorageCategory =
            lower.contains("cache") ? .caches :
            lower.contains("build") || lower.contains("dist") ? .builds :
            lower.contains("worktree") ? .worktrees :
            lower.contains("container") || lower.contains("docker") ? .containers :
            lower.contains("model") ? .models : .data
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cat.accent.opacity(0.2))
                .frame(width: 28, height: 28)
            Image(systemName: cat.symbol)
                .font(.system(size: 12))
                .foregroundStyle(cat.accent)
        }
    }

    private func startReview() async {
        if useAgent {
            let payload = SkillComposer.reviewingPayload(project: project, store: store)
            let prompt = SkillComposer.compose(payload)
            let root = store.projectRoot(for: project)
            conductor.milestones = ["Composing skills for Reviewing…"]
            await supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
            conductor.usage = supervisor.usage
            conductor.buildLocalOnly(store: store, project: project, agent: agent)
            conductor.milestones.append("Agent finished: \(supervisor.status)")
        } else {
            conductor.buildLocalOnly(store: store, project: project, agent: agent)
        }
    }

    private func volumeFreeBytes() -> Int64? {
        let root = store.projectRoot(for: project)
        let values = try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}

/// S10 Result — selected / moved / measured free-space delta.
struct ResultPanel: View {
    @ObservedObject var model: AppModel
    var freeBefore: Int64?
    var freeAfter: Int64?

    private var conductor: RunConductor { model.conductor }
    private var store: TraceStore { model.store }

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
                        Text(result.path)
                            .font(.caption.monospaced())
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
