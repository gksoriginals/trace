import SwiftUI

/// Previous Reviewing runs — local app database only.
struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedId: String?

    private var store: TraceStore { model.store }

    private var entries: [RunHistoryEntry] { store.runHistory }

    private var selected: RunHistoryEntry? {
        if let selectedId {
            return entries.first { $0.id == selectedId }
        }
        return entries.first
    }

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
            .padding(.horizontal, TraceSpace.windowPad)
            .padding(.vertical, TraceSpace.md)
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
                HStack(alignment: .top, spacing: 0) {
                    indexPane
                        .frame(width: 300)
                    Divider().overlay(TraceColor.line.opacity(0.35))
                    detailPane
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(TraceColor.canvas)
        .onAppear {
            if selectedId == nil {
                selectedId = entries.first?.id
            }
        }
        .onChange(of: entries.map(\.id)) { _, ids in
            if let selectedId, ids.contains(selectedId) { return }
            self.selectedId = ids.first
        }
    }

    private var indexPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraceSpace.sm) {
                Text("\(entries.count) run\(entries.count == 1 ? "" : "s")")
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
                    .padding(.bottom, 4)

                ForEach(entries) { entry in
                    let on = selected?.id == entry.id
                    Button {
                        selectedId = entry.id
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: TraceSpace.sm) {
                                statusDot(entry.status)
                                Text(entry.scopeLabel)
                                    .font(TraceType.bodyMedium)
                                    .foregroundStyle(TraceColor.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            Text(Self.displayDate(entry.finishedAt))
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                            Text(entry.summary)
                                .font(TraceType.meta)
                                .foregroundStyle(TraceColor.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(TraceSpace.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                                .fill(on ? TraceColor.elevated : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                                .stroke(on ? TraceColor.brand.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(TraceSpace.md)
        }
        .background(TraceColor.canvas)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let entry = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: TraceSpace.lg) {
                    HStack(alignment: .firstTextBaseline, spacing: TraceSpace.md) {
                        statusDot(entry.status)
                        Text(entry.status.capitalized)
                            .font(TraceType.section)
                            .foregroundStyle(statusColor(entry.status))
                        Spacer()
                        Text(AgentKind(rawValue: entry.agent)?.title ?? entry.agent)
                            .font(TraceType.caption)
                            .foregroundStyle(TraceColor.brand)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(TraceColor.elevated)
                            )
                    }

                    VStack(alignment: .leading, spacing: TraceSpace.xs) {
                        Text(entry.scopeLabel)
                            .font(TraceType.bodyMedium)
                            .foregroundStyle(TraceColor.textPrimary)
                        Text("Started \(Self.displayDate(entry.startedAt)) · Finished \(Self.displayDate(entry.finishedAt))")
                            .font(TraceType.meta)
                            .foregroundStyle(TraceColor.textSecondary)
                        if let root = entry.rootPath, !root.isEmpty {
                            PathLabel(path: root)
                        }
                    }

                    Text(entry.summary)
                        .font(TraceType.body)
                        .foregroundStyle(TraceColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: TraceSpace.lg) {
                        metaChip("Projects", "\(entry.projectIds.count)")
                        metaChip("Decide later", "\(entry.openDecideLaterCount)")
                        if let usage = entry.usage, usage.available {
                            metaChip("Usage", usage.display)
                        }
                    }

                    if !entry.projectIds.isEmpty {
                        VStack(alignment: .leading, spacing: TraceSpace.xs) {
                            Text("Scope")
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                            Text(entry.projectIds.joined(separator: ", "))
                                .font(TraceType.path)
                                .foregroundStyle(TraceColor.textPrimary)
                                .textSelection(.enabled)
                        }
                    }

                    let log = CodexSession.meaningfulLogLines(entry.logTail)
                    if !log.isEmpty {
                        VStack(alignment: .leading, spacing: TraceSpace.sm) {
                            Text("Log tail")
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(TraceType.path)
                                        .foregroundStyle(TraceColor.textPrimary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(TraceSpace.md)
                            .background(
                                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                                    .fill(TraceColor.elevated)
                            )
                        }
                    }

                    HStack(spacing: TraceSpace.sm) {
                        Button {
                            Task { await model.runInPlace(.allPermitted) }
                        } label: {
                            Label("Run again", systemImage: TraceSymbol.run)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                        .disabled(model.supervisor.isBusy || store.projects.isEmpty)

                        if entry.openDecideLaterCount > 0, let first = store.decideLater.first {
                            Button("Review decide later") {
                                model.destination = .decideLaterQueue
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(TraceSpace.windowPad)
            }
        } else {
            Text("Select a run.")
                .foregroundStyle(TraceColor.textSecondary)
                .padding(TraceSpace.windowPad)
        }
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
