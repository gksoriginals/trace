import SwiftUI

/// Project surface from a Home card: insights, runs, Decide later, memory — one place.
/// No folder dropdown (Back → Home). Global History remains on the rail.
struct MemoryView: View {
    @ObservedObject var model: AppModel
    var projectId: String?

    @State private var expandedRunId: String?

    private var store: TraceStore { model.store }

    private var project: ProjectIndexRow? {
        guard let projectId else { return nil }
        return store.projects.first { $0.id == projectId }
    }

    private var events: [MemoryEvent] {
        guard let projectId else { return [] }
        return store.events(for: projectId).reversed()
    }

    private var runs: [RunHistoryEntry] {
        guard let projectId else { return [] }
        return store.runs(for: projectId)
    }

    private var queueItems: [DecideLaterItem] {
        guard let projectId else { return [] }
        return store.decideLater.filter { ($0.project_id ?? "") == projectId || $0.project_id == nil }
            .filter { item in
                // Prefer exact project match; include nil-project only when single-project scope.
                if let pid = item.project_id { return pid == projectId }
                return runs.contains { $0.projectIds.count == 1 && $0.projectIds.contains(projectId) }
            }
    }

    private var insights: String {
        guard let projectId else { return "" }
        return store.insightBodies[projectId] ?? ""
    }

    var body: some View {
        Group {
            if let projectId, let project {
                projectSurface(projectId: projectId, project: project)
            } else {
                chooseProject
            }
        }
        .background(TraceColor.canvas)
        .onAppear { backfillReceiptIfNeeded() }
        .onChange(of: projectId) { _, _ in
            expandedRunId = nil
            backfillReceiptIfNeeded()
        }
    }

    private func backfillReceiptIfNeeded() {
        guard let projectId, let project else { return }
        let body = store.insightBodies[projectId] ?? ""
        guard body.isEmpty, let last = store.runs(for: projectId).first else { return }
        store.writeRunReceipts(projects: [project], entry: last)
    }

    private var chooseProject: some View {
        VStack(alignment: .leading, spacing: 0) {
            TracePageBar {
                Text("Projects")
                    .font(TraceType.section)
                    .foregroundStyle(TraceColor.textPrimary)
            } trailing: {
                EmptyView()
            }
            Divider().overlay(TraceColor.line.opacity(0.35))
            if store.projects.isEmpty {
                Text("Add a project folder from Home.")
                    .font(TraceType.body)
                    .foregroundStyle(TraceColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TraceSpace.sm) {
                        Text("Open a Home card, or pick a project.")
                            .font(TraceType.meta)
                            .foregroundStyle(TraceColor.textSecondary)
                        ForEach(store.projects) { p in
                            Button {
                                model.destination = .memory(p.id)
                            } label: {
                                HStack {
                                    Text(p.displayName)
                                        .font(TraceType.bodyMedium)
                                        .foregroundStyle(TraceColor.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(TraceColor.textSecondary)
                                }
                                .padding(TraceSpace.md)
                                .background(
                                    RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                                        .fill(TraceColor.surface)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(TraceSpace.windowPad)
                }
            }
        }
    }

    private func projectSurface(projectId: String, project: ProjectIndexRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TracePageBar {
                HStack(spacing: TraceSpace.sm) {
                    Button {
                        model.destination = .home
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: TraceSpace.hit, height: TraceSpace.hit)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Back to Home")
                    .accessibilityLabel("Back to Home")

                    Text(project.displayName)
                        .font(TraceType.section)
                        .foregroundStyle(TraceColor.textPrimary)
                        .lineLimit(1)
                }
            } trailing: {
                Button {
                    Task { await model.runInPlace(.project(project)) }
                } label: {
                    Label("Run", systemImage: TraceSymbol.run)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .controlSize(.small)
                .disabled(model.supervisor.isBusy)
            }

            Divider().overlay(TraceColor.line.opacity(0.35))

            ScrollView {
                VStack(alignment: .leading, spacing: TraceSpace.lg) {
                    if let root = project.roots?.first {
                        PathLabel(path: root)
                    }

                    sectionCard(title: "Insights") {
                        if insights.isEmpty {
                            Text("No insights yet. Run this project to record what happened — even when nothing was proposed for Trash.")
                                .font(TraceType.body)
                                .foregroundStyle(TraceColor.textSecondary)
                        } else {
                            Text(insights)
                                .font(TraceType.body)
                                .foregroundStyle(TraceColor.textPrimary)
                                .textSelection(.enabled)
                        }
                    }

                    sectionCard(title: "History") {
                        if runs.isEmpty {
                            Text("No runs for this project yet.")
                                .font(TraceType.body)
                                .foregroundStyle(TraceColor.textSecondary)
                        } else {
                            ForEach(runs.prefix(8)) { entry in
                                runRow(entry)
                            }
                            Button {
                                model.destination = .history
                            } label: {
                                Text("Open full History")
                                    .font(TraceType.caption)
                                    .foregroundStyle(TraceColor.brand)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }

                    // Only show sections that have content — no empty “No memory events” dead ends.
                    let decideItems = store.decideLater.filter { $0.project_id == projectId }
                    if !decideItems.isEmpty {
                        sectionCard(title: "Decide later") {
                            ForEach(decideItems) { item in
                                Button {
                                    model.destination = .decideLaterItem(item.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.action ?? item.artifact_id ?? item.id)
                                            .font(TraceType.bodyMedium)
                                            .foregroundStyle(TraceColor.textPrimary)
                                        if let why = item.why_doubtful, !why.isEmpty {
                                            Text(why)
                                                .font(TraceType.meta)
                                                .foregroundStyle(TraceColor.textSecondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !events.isEmpty {
                        sectionCard(title: "Memory") {
                            ForEach(events.prefix(20)) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(indexTitle(event))
                                        .font(TraceType.bodyMedium)
                                        .foregroundStyle(TraceColor.textPrimary)
                                    Text(indexKind(event))
                                        .font(TraceType.caption)
                                        .foregroundStyle(TraceColor.textSecondary)
                                    if let why = event.why, !why.isEmpty {
                                        Text(why)
                                            .font(TraceType.meta)
                                            .foregroundStyle(TraceColor.textSecondary)
                                            .lineLimit(4)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Button {
                        model.openAsk(projectId: projectId, itemId: nil)
                    } label: {
                        Label("Ask about this project", systemImage: TraceSymbol.ask)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                }
                .padding(TraceSpace.windowPad)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            Text(title)
                .font(TraceType.caption)
                .foregroundStyle(TraceColor.textSecondary)
            content()
        }
        .padding(TraceSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                .fill(TraceColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                .stroke(TraceColor.line.opacity(0.35), lineWidth: 1)
        )
    }

    private func runRow(_ entry: RunHistoryEntry) -> some View {
        let open = expandedRunId == entry.id
        let log = CodexSession.meaningfulLogLines(entry.logTail)
        return VStack(alignment: .leading, spacing: TraceSpace.sm) {
            Button {
                expandedRunId = open ? nil : entry.id
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(statusColor(entry.status))
                            .frame(width: 8, height: 8)
                        Text(entry.status.capitalized)
                            .font(TraceType.bodyMedium)
                            .foregroundStyle(TraceColor.textPrimary)
                        Text(AgentKind(rawValue: entry.agent)?.title ?? entry.agent)
                            .font(TraceType.caption)
                            .foregroundStyle(TraceColor.brand)
                        Spacer()
                        Text(Self.displayDate(entry.finishedAt))
                            .font(TraceType.caption)
                            .foregroundStyle(TraceColor.textSecondary)
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(TraceColor.textSecondary)
                    }
                    Text(entry.summary)
                        .font(TraceType.meta)
                        .foregroundStyle(TraceColor.textSecondary)
                        .lineLimit(open ? 8 : 2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                HStack(spacing: TraceSpace.lg) {
                    meta("Decide later", "\(entry.openDecideLaterCount)")
                    if let usage = entry.usage, usage.available {
                        meta("Usage", usage.display)
                    }
                }
                if !log.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log")
                            .font(TraceType.caption)
                            .foregroundStyle(TraceColor.textSecondary)
                        ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(TraceType.path)
                                .foregroundStyle(TraceColor.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(TraceSpace.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(TraceColor.elevated)
                    )
                }
            }
        }
        .padding(TraceSpace.sm)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(TraceColor.elevated.opacity(0.45))
        )
    }

    private func meta(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(TraceType.caption).foregroundStyle(TraceColor.textSecondary)
            Text(value).font(TraceType.bodyMedium).foregroundStyle(TraceColor.textPrimary)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return TraceColor.safe
        case "cancelled": return TraceColor.review
        default: return TraceColor.critical
        }
    }

    private func indexTitle(_ event: MemoryEvent) -> String {
        if let location = event.what?.location {
            return URL(fileURLWithPath: location).lastPathComponent
        }
        return event.event_type ?? event.id
    }

    private func indexKind(_ event: MemoryEvent) -> String {
        if event.claim != nil { return "inferred" }
        if event.correction_of != nil { return "correction" }
        return "fact"
    }

    private static func displayDate(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: iso)
        if date == nil {
            parser.formatOptions = [.withInternetDateTime]
            date = parser.date(from: iso)
        }
        guard let date else { return iso }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
