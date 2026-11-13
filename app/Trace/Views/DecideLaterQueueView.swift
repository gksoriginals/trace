import SwiftUI

/// Full Decide-later queue surface — opened from the right-rail diamond, not a popup menu.
struct DecideLaterQueueView: View {
    @ObservedObject var model: AppModel

    private var store: TraceStore { model.store }
    private var items: [DecideLaterItem] { store.decideLater }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TracePageBar {
                HStack(spacing: TraceSpace.sm) {
                    Image(systemName: TraceSymbol.decideLater)
                        .foregroundStyle(TraceColor.review)
                    Text("Decide later")
                        .font(TraceType.section)
                        .foregroundStyle(TraceColor.textPrimary)
                }
            } trailing: {
                Text(items.isEmpty ? "Nothing waiting" : "\(items.count) open")
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
                    .monospacedDigit()
            }

            Divider().overlay(TraceColor.line.opacity(0.35))

            if items.isEmpty {
                Text("Nothing waiting for a decision. Runs and skills add doubtful leftovers here.")
                    .font(TraceType.body)
                    .foregroundStyle(TraceColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(TraceSpace.xxl)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TraceSpace.md) {
                        ForEach(items) { item in
                            DecideLaterQueueRow(model: model, item: item)
                        }
                    }
                    .padding(TraceSpace.windowPad)
                }
            }
        }
        .background(TraceColor.canvas)
    }
}

private struct DecideLaterQueueRow: View {
    @ObservedObject var model: AppModel
    let item: DecideLaterItem

    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            Button {
                model.destination = .decideLaterItem(item.id)
            } label: {
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
                    if let why = item.why_doubtful, !why.isEmpty {
                        Text(why)
                            .font(TraceType.meta)
                            .foregroundStyle(TraceColor.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: TraceSpace.sm) {
                        if let project = item.project_id {
                            Text(project)
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                        }
                        if let bytes = item.bytes {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Button {
                    model.destination = .decideLaterItem(item.id)
                } label: {
                    Text("Open")
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
            }
        }
        .traceCard(compact: true)
    }
}
