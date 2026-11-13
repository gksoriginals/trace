import SwiftUI

/// Previous Reviewing runs — local app database only.
struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var expandedIds: Set<String> = []

    private var store: TraceStore { model.store }

    private var entries: [RunHistoryEntry] { store.runHistory }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                TraceScreenHeader(
                    title: "History",
                    subtitle: "Previous runs on this Mac. Local only — not a transcript dump."
                )
                Spacer(minLength: TraceSpace.md)
                TraceToolbarButton(title: "Refresh", symbol: "arrow.clockwise") {
                    store.refresh()
                }
            }
            .padding(.horizontal, TraceSpace.lg)
            .padding(.vertical, TraceSpace.sm)
            .background(TraceColor.surface)

            Divider().overlay(TraceColor.line.opacity(0.35))

            if entries.isEmpty {
                TraceStatusBanner(
                    kind: .info,
                    title: "No runs yet",
                    detail: "When you Run from Home, each finished pass shows up here.",
                    primaryTitle: "Go to Home",
                    primaryAction: { model.destination = .home }
                )
                .padding(TraceSpace.windowPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 360, maximum: 720), spacing: TraceSpace.md)],
                        alignment: .leading,
                        spacing: TraceSpace.md
                    ) {
                        ForEach(entries) { entry in
                            historyCard(entry)
                        }
                    }
                    .padding(TraceSpace.lg)
                }
            }
        }
        .background(TraceColor.canvas)
        .onChange(of: entries.map(\.id)) { _, ids in
            expandedIds.formIntersection(ids)
        }
    }

    private func historyCard(_ entry: RunHistoryEntry) -> some View {
        let expanded = expandedIds.contains(entry.id)
        return VStack(alignment: .leading, spacing: TraceSpace.sm) {
            Button {
                if expanded { expandedIds.remove(entry.id) }
                else { expandedIds.insert(entry.id) }
            } label: {
                VStack(alignment: .leading, spacing: TraceSpace.sm) {
                    HStack(spacing: TraceSpace.sm) {
                        statusDot(entry.status)
                        Text(entry.scopeLabel)
                            .font(TraceType.bodyMedium)
                            .foregroundStyle(TraceColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(entry.status.capitalized)
                            .font(TraceType.caption)
                            .foregroundStyle(statusColor(entry.status))
                        Text(AgentKind(rawValue: entry.agent)?.title ?? entry.agent)
                            .font(TraceType.caption)
                            .foregroundStyle(TraceColor.brand)
                    }
                    Text(Self.displayDate(entry.finishedAt))
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.textSecondary)
                    Text(entry.summary)
                        .font(TraceType.meta)
                        .foregroundStyle(TraceColor.textSecondary)
                        .lineLimit(expanded ? nil : 3)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: TraceSpace.lg) {
                        metaChip("Projects", "\(entry.projectIds.count)")
                        metaChip("Decide later", "\(entry.openDecideLaterCount)")
                        if let usage = entry.usage, usage.available {
                            metaChip("Usage", usage.display)
                        }
                    }
                    Label(expanded ? "Hide details" : "Show details",
                          systemImage: expanded ? "chevron.up" : "chevron.down")
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.brand)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .traceCard(elevated: expanded, selected: expanded, compact: true)

            if expanded { runDetails(entry) }
        }
    }

    private func runDetails(_ entry: RunHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            Text("Started \(Self.displayDate(entry.startedAt)) · Finished \(Self.displayDate(entry.finishedAt))")
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)
            if let root = entry.rootPath, !root.isEmpty { PathLabel(path: root) }
            if !entry.projectIds.isEmpty {
                VStack(alignment: .leading, spacing: TraceSpace.xs) {
                    Text("Scope").font(TraceType.caption).foregroundStyle(TraceColor.textSecondary)
                    Text(entry.projectIds.joined(separator: ", "))
                        .font(TraceType.path)
                        .foregroundStyle(TraceColor.textPrimary)
                        .textSelection(.enabled)
                }
            }
            let log = CodexSession.meaningfulLogLines(entry.logTail)
            if !log.isEmpty {
                VStack(alignment: .leading, spacing: TraceSpace.xs) {
                    Text("Log tail").font(TraceType.caption).foregroundStyle(TraceColor.textSecondary)
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(TraceType.path)
                            .foregroundStyle(TraceColor.textPrimary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TraceSpace.md)
                .background(RoundedRectangle(cornerRadius: TraceSpace.radius).fill(TraceColor.elevated))
            }
            HStack(spacing: TraceSpace.sm) {
                Button { Task { await model.runInPlace(.allPermitted) } } label: {
                    Label("Run again", systemImage: TraceSymbol.run)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .disabled(model.supervisor.isBusy || store.projects.isEmpty)
                if entry.openDecideLaterCount > 0 {
                    Button("Review decide later") { model.destination = .decideLaterQueue }
                        .buttonStyle(.bordered)
                }
            }
        }
        .traceCard(compact: true)
    }

    private func metaChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(TraceType.caption)
                .foregroundStyle(TraceColor.textSecondary)
            Text(value)
                .font(TraceType.bodyMedium)
                .foregroundStyle(TraceColor.textPrimary)
                .monospacedDigit()
        }
    }

    private func statusDot(_ status: String) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return TraceColor.safe
        case "cancelled": return TraceColor.review
        default: return TraceColor.critical
        }
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
