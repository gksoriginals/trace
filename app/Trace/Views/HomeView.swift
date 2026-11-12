import SwiftUI

/// S5 Home — Decide later lane + project insight cards. Local only on open.
struct HomeView: View {
    @ObservedObject var model: AppModel

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let error = store.loadError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(TraceColor.critical)
                        .traceCard()
                }
                decideLaterLane
                insightsLane
                if supervisor.isBusy || !supervisor.log.isEmpty {
                    sessionPanel
                }
            }
            .padding(32)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .background(TraceColor.canvas)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Home")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(TraceColor.textPrimary)
                Text("Local files only — no model call and no disk scan to open this screen.")
                    .font(.system(size: 13))
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Spacer()
            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button {
                model.openAsk(projectId: nil, itemId: nil)
            } label: {
                Label("Ask Trace", systemImage: TraceSymbol.ask)
            }
            .buttonStyle(.borderedProminent)
            .tint(TraceColor.brand)
            .keyboardShortcut("k", modifiers: .command)
        }
    }

    private var decideLaterLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Decide later", systemImage: TraceSymbol.decideLater)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TraceColor.textPrimary)
                Spacer()
                Text("\(store.decideLater.count) open")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }

            if store.decideLater.isEmpty {
                Text("No open doubts. Skills write here when a decision is unclear.")
                    .foregroundStyle(TraceColor.textSecondary)
                    .traceCard(elevated: true)
            } else {
                ForEach(store.decideLater) { item in
                    Button {
                        model.destination = .decideLater(item.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: TraceSymbol.decideLater)
                                .foregroundStyle(TraceColor.review)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.action ?? item.artifact_id ?? item.id)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(TraceColor.textPrimary)
                                    Spacer()
                                    Text(item.status ?? "open")
                                        .font(.caption)
                                        .foregroundStyle(TraceColor.textSecondary)
                                }
                                Text(item.why_doubtful ?? "Needs a closer look before any action.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(TraceColor.textSecondary)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    if let pid = item.project_id {
                                        Text(pid)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(TraceColor.textSecondary)
                                    }
                                    OriginBadge(origin: .skill)
                                    Spacer()
                                    Button("Keep") {
                                        store.updateQueueStatus(id: item.id, status: "kept")
                                    }
                                    .buttonStyle(.bordered)
                                    Button("Defer") {
                                        store.updateQueueStatus(id: item.id, status: "deferred")
                                    }
                                    .buttonStyle(.bordered)
                                    Button("Ask") {
                                        model.openAsk(projectId: item.project_id, itemId: item.id)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(TraceColor.brand)
                                }
                            }
                        }
                        .traceCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var insightsLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TraceColor.textPrimary)

            if store.insights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No projects in ~/.trace/index.md yet.")
                    Text("Finish Setup, install skills, and work in a project. Home stays local until then.")
                        .foregroundStyle(TraceColor.textSecondary)
                    Button("Open Setup") { model.destination = .setup }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                }
                .traceCard(elevated: true)
            }

            ForEach(store.insights) { insight in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        categoryMark(for: insight)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.project.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(TraceColor.textPrimary)
                            Text((insight.project.roots ?? []).joined(separator: ", "))
                                .font(.caption.monospaced())
                                .foregroundStyle(TraceColor.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        AgentBadge(kind: preferredAgent, compact: true)
                        if insight.openQueueCount > 0 {
                            Label("\(insight.openQueueCount)", systemImage: TraceSymbol.decideLater)
                                .font(.caption)
                                .foregroundStyle(TraceColor.review)
                        }
                    }

                    let body = store.insightBodies[insight.project.id] ?? ""
                    if body.isEmpty {
                        ForEach(insight.recentEvents.prefix(3)) { event in
                            HStack(alignment: .top, spacing: 8) {
                                OriginBadge(origin: .skill)
                                Text("\(event.event_type ?? "event"): \(event.why ?? event.what?.location ?? event.event_id)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TraceColor.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        if insight.recentEvents.isEmpty {
                            Text("No memory events yet — skills write as you work.")
                                .font(.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                        }
                    } else {
                        Text(body)
                            .font(.system(size: 13))
                            .foregroundStyle(TraceColor.textSecondary)
                            .lineLimit(10)
                    }

                    HStack {
                        Button {
                            Task { await refreshInsights(insight.project) }
                        } label: {
                            Label("Refresh insights", systemImage: "sparkles")
                        }
                        Button("Ask") { model.openAsk(projectId: insight.project.id, itemId: nil) }
                        Button {
                            model.conductor.stage = .reviewing
                            model.conductor.cards = []
                            model.conductor.milestones = []
                            model.destination = .run(insight.project)
                        } label: {
                            Label("Run", systemImage: TraceSymbol.run)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                        Button("Memory") { model.destination = .memory(insight.project.id) }
                        Spacer()
                    }
                }
                .traceCard()
            }
        }
    }

    private func categoryMark(for insight: ProjectInsight) -> some View {
        let cat = StorageCategory.caches
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cat.accent.opacity(0.18))
                .frame(width: 40, height: 40)
            Image(systemName: cat.symbol)
                .foregroundStyle(cat.accent)
        }
        .accessibilityLabel("Project storage")
    }

    private var preferredAgent: AgentKind {
        AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Agent session", systemImage: TraceSymbol.run)
                    .font(.system(size: 14, weight: .semibold))
                Text(supervisor.status)
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
                Spacer()
                Text("Usage: \(supervisor.usage.display)")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            ScrollView {
                Text(supervisor.log.suffix(24).joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
            if supervisor.pendingPermission != nil {
                HStack {
                    Button("Allow once") { Task { await supervisor.replyToPermission(allow: true) } }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                    Button("Reject") { Task { await supervisor.replyToPermission(allow: false) } }
                }
            }
            Button {
                Task { await supervisor.cancel() }
            } label: {
                Label("Stop", systemImage: TraceSymbol.stop)
            }
        }
        .traceCard(elevated: true)
    }

    private func refreshInsights(_ project: ProjectIndexRow) async {
        let agent = preferredAgent
        let payload = SkillComposer.prepareHomePayload(project: project, store: store)
        let prompt = SkillComposer.compose(payload)
        let root = store.projectRoot(for: project)
        await supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
        store.refresh()
    }
}
