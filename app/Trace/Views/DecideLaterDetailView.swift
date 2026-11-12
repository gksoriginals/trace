import SwiftUI

struct DecideLaterDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    let itemId: String
    var onAsk: () -> Void

    private var item: DecideLaterItem? {
        store.decideLater.first { $0.id == itemId }
            ?? store.insights.flatMap { insight -> [DecideLaterItem] in
                LocalEvidence.loadQueue(nearMemoryLog: insight.project.memory_log)
                    .map { LocalEvidence.mergeStatus($0, overrides: store.preferences.queueOverrides) }
            }.first { $0.id == itemId }
    }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.action)
                        .font(.system(size: 20, weight: .semibold))
                    labelled("Status", item.status)
                    labelled("Why doubtful", item.why_doubtful)
                    if let resolve = item.would_resolve {
                        labelled("Would resolve", resolve)
                    }
                    labelled("Project", item.project_id)
                    labelled("Agent", item.agent)
                    if let bytes = item.bytes {
                        labelled("Bytes", "\(bytes)")
                    } else {
                        labelled("Bytes", "unknown")
                    }
                    Text("Plan action is not consent. Execute ships in M2.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Keep this time") {
                            store.setQueueStatus(id: item.id, status: "kept")
                            store.route = .home
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceTheme.safe(scheme))

                        Button("Defer") {
                            store.setQueueStatus(id: item.id, status: "deferred")
                            store.route = .home
                        }
                        .buttonStyle(.bordered)

                        Button("Ask") { onAsk() }
                            .buttonStyle(.bordered)

                        Button("Back") { store.route = .home }
                    }
                }
                .padding(24)
            } else {
                Text("Item not found.")
                    .padding(24)
            }
        }
        .background(TraceTheme.canvas(scheme))
        .navigationTitle("Decide later")
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13))
        }
    }
}
