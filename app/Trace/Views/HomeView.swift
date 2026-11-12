import SwiftUI

/// S5 Home — Decide later lane + project insight cards. Local only on open.
struct HomeView: View {
    @ObservedObject var model: AppModel

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraceSpace.xl) {
                header
                if let error = store.loadError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(TraceType.body)
                        .foregroundStyle(TraceColor.critical)
                        .traceCard(elevated: true)
                        .accessibilityAddTraits(.isStaticText)
                }
                decideLaterLane
                insightsLane
                if supervisor.isBusy || !supervisor.log.isEmpty {
                    sessionPanel
                }
            }
            .padding(TraceSpace.xxl)
            .frame(maxWidth: TraceSpace.contentMax, alignment: .leading)
        }
        .background(TraceColor.canvas)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: TraceSpace.lg) {
            TraceScreenHeader(
                title: "Home",
                subtitle: "Local files only — no model call and no disk scan to open this screen."
            )
            Spacer(minLength: TraceSpace.md)
            HStack(spacing: TraceSpace.sm) {
                TraceToolbarButton(title: "Refresh", symbol: "arrow.clockwise") {
                    store.refresh()
                }
                .help("Reload local index and queues")

                Menu {
                    Button("Ask Trace") { model.openAsk(projectId: nil, itemId: nil) }
                    Divider()
                    Button("Run all projects") {
                        startRun(.allPermitted)
                    }
                    .disabled(store.projects.isEmpty)
                    Button("Open Setup") { model.destination = .setup }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(minHeight: TraceSpace.hit)
                .help("More Home actions")
            }
        }
    }

    private var decideLaterLane: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            HStack {
                TraceSectionLabel(title: "Decide later", symbol: TraceSymbol.decideLater)
                Spacer()
                Text("\(store.decideLater.count) open")
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
                    .monospacedDigit()
            }

            if store.decideLater.isEmpty {
                Text("No open doubts. Skills write here when a decision is unclear.")
                    .font(TraceType.body)
                    .foregroundStyle(TraceColor.textSecondary)
                    .traceCard(elevated: true)
            } else {
                ForEach(store.decideLater) { item in
                    DecideLaterRow(model: model, item: item)
                }
            }
        }
    }

    private var insightsLane: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            TraceSectionLabel(title: "Projects")

            if store.insights.isEmpty {
                VStack(alignment: .leading, spacing: TraceSpace.sm) {
                    Text("No projects in ~/.trace/index.md yet.")
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                    Text("Finish Setup, install skills, and work in a project. Home stays local until then.")
                        .font(TraceType.body)
                        .foregroundStyle(TraceColor.textSecondary)
                    Button("Open Setup") { model.destination = .setup }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                }
                .traceCard(elevated: true)
            }

            ForEach(store.insights) { insight in
                ProjectInsightCard(model: model, insight: insight) {
                    startRun(.project(insight.project))
                }
            }
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            HStack {
                Label("Agent session", systemImage: TraceSymbol.run)
                    .font(TraceType.bodyMedium)
                Text(supervisor.status)
                    .font(TraceType.caption)
                    .foregroundStyle(TraceColor.textSecondary)
                Spacer()
                Text("Usage: \(supervisor.usage.display)")
                    .font(TraceType.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            ScrollView {
                Text(supervisor.log.suffix(24).joined(separator: "\n"))
                    .font(TraceType.path)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
            if supervisor.pendingPermission != nil {
                HStack(spacing: TraceSpace.sm) {
                    Button("Allow once") { Task { await supervisor.replyToPermission(allow: true) } }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                    Button("Reject") { Task { await supervisor.replyToPermission(allow: false) } }
                        .buttonStyle(.bordered)
                }
            }
            Button {
                Task { await supervisor.cancel() }
            } label: {
                Label("Stop", systemImage: TraceSymbol.stop)
            }
            .buttonStyle(.bordered)
        }
        .traceCard(elevated: true)
    }

    private func startRun(_ scope: AppModel.RunScope) {
        model.conductor.stage = .reviewing
        model.conductor.cards = []
        model.conductor.milestones = []
        model.destination = .run(scope)
    }
}

/// Separate hit regions: body opens detail; Keep/Defer/Ask are their own controls (design.md cards rule).
private struct DecideLaterRow: View {
    @ObservedObject var model: AppModel
    let item: DecideLaterItem

    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            Button {
                model.destination = .decideLater(item.id)
            } label: {
                HStack(alignment: .top, spacing: TraceSpace.md) {
                    Image(systemName: TraceSymbol.decideLater)
                        .foregroundStyle(TraceColor.review)
                        .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: TraceSpace.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.action ?? item.artifact_id ?? item.id)
                                .font(TraceType.bodyMedium)
                                .foregroundStyle(TraceColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: TraceSpace.sm)
                            Text(item.status ?? "open")
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                        }
                        Text(item.why_doubtful ?? "Needs a closer look before any action.")
                            .font(TraceType.body)
                            .foregroundStyle(TraceColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        HStack(spacing: TraceSpace.sm) {
                            if let pid = item.project_id {
                                Text(pid)
                                    .font(TraceType.path)
                                    .foregroundStyle(TraceColor.textSecondary)
                                    .lineLimit(1)
                            }
                            OriginBadge(origin: .skill)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Decide later item")
            .accessibilityValue(item.action ?? item.id)

            HStack(spacing: TraceSpace.sm) {
                Button("Keep") {
                    model.store.updateQueueStatus(id: item.id, status: "kept")
                }
                .buttonStyle(.bordered)
                Button("Defer") {
                    model.store.updateQueueStatus(id: item.id, status: "deferred")
                }
                .buttonStyle(.bordered)
                Button {
                    model.openAsk(projectId: item.project_id, itemId: item.id)
                } label: {
                    Label("Ask", systemImage: TraceSymbol.ask)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                Spacer(minLength: 0)
            }
        }
        .traceCard()
    }
}

private struct ProjectInsightCard: View {
    @ObservedObject var model: AppModel
    let insight: ProjectInsight
    let onRun: () -> Void

    private var store: TraceStore { model.store }

    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            HStack(alignment: .top, spacing: TraceSpace.md) {
                CategoryLeadingMark(category: .caches)
                VStack(alignment: .leading, spacing: TraceSpace.xs) {
                    Text(insight.project.displayName)
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                    if let roots = insight.project.roots, let first = roots.first {
                        PathLabel(path: first)
                    }
                }
                Spacer(minLength: TraceSpace.sm)
                AgentBadge(kind: preferredAgent, compact: true)
                if insight.openQueueCount > 0 {
                    Label("\(insight.openQueueCount)", systemImage: TraceSymbol.decideLater)
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.review)
                        .help("\(insight.openQueueCount) open Decide later items")
                }
            }

            insightBody

            HStack(spacing: TraceSpace.sm) {
                TraceToolbarButton(title: "Refresh insights", symbol: "sparkles") {
                    Task { await refreshInsights() }
                }
                TraceToolbarButton(title: "Ask", symbol: TraceSymbol.ask) {
                    model.openAsk(projectId: insight.project.id, itemId: nil)
                }
                Button {
                    onRun()
                } label: {
                    Label("Run project", systemImage: TraceSymbol.run)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .help("Deep Run for this project only")

                TraceToolbarButton(title: "Memory", symbol: TraceSymbol.memory) {
                    model.destination = .memory(insight.project.id)
                }
                Spacer(minLength: 0)
            }
        }
        .traceCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Project \(insight.project.displayName)")
    }

    @ViewBuilder
    private var insightBody: some View {
        let body = store.insightBodies[insight.project.id] ?? ""
        if body.isEmpty {
            if insight.recentEvents.isEmpty {
                Text("No memory events yet — skills write as you work.")
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
            } else {
                ForEach(insight.recentEvents.prefix(3)) { event in
                    HStack(alignment: .top, spacing: TraceSpace.sm) {
                        OriginBadge(origin: .skill)
                        Text("\(event.event_type ?? "event"): \(event.why ?? event.what?.location ?? event.event_id)")
                            .font(TraceType.meta)
                            .foregroundStyle(TraceColor.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        } else {
            Text(body)
                .font(TraceType.body)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(8)
        }
    }

    private var preferredAgent: AgentKind {
        AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
    }

    private func refreshInsights() async {
        let agent = preferredAgent
        let payload = SkillComposer.prepareHomePayload(project: insight.project, store: store)
        let prompt = SkillComposer.compose(payload)
        let root = store.projectRoot(for: insight.project)
        await model.supervisor.start(kind: agent, projectRoot: root, resumeId: nil, prompt: prompt)
        store.refresh()
    }
}
