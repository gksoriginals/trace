import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    var projectId: String?

    private var insights: [ProjectInsight] {
        if let projectId {
            return store.insights.filter { $0.id == projectId }
        }
        return store.insights
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Memory")
                    .font(.system(size: 20, weight: .semibold))
                Text("Evidence-linked events from skill logs. Editing corrections ships more fully later; M1 is read-first.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(insights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(insight.project.name)
                            .font(.system(size: 15, weight: .semibold))
                        Text(insight.project.memory_log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        ForEach(insight.events) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(event.event_id)
                                        .font(.system(size: 11, design: .monospaced))
                                    Text(event.claim ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(event.event_type)
                                        .font(.caption2)
                                        .foregroundStyle(TraceTheme.brand(scheme))
                                }
                                Text(event.why ?? "")
                                    .font(.system(size: 12))
                                if let when = event.can_go_when {
                                    Text("can_go_when: \(when)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TraceTheme.surface(scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(TraceTheme.canvas(scheme))
        .onAppear { store.refreshEvidence() }
    }
}
