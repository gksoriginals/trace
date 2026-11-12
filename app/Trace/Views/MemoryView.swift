import SwiftUI

/// S12 Memory / Learnings — facts vs claims, sources, setup history.
struct MemoryView: View {
    @ObservedObject var model: AppModel
    var projectId: String?

    @State private var selectedProjectId: String = ""

    private var store: TraceStore { model.store }

    private var events: [MemoryEvent] {
        let id = selectedProjectId.isEmpty ? (projectId ?? store.projects.first?.id ?? "") : selectedProjectId
        return store.events(for: id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Memory")
                    .font(.system(size: 28, weight: .semibold))
                Text("Local provenance. Corrections preserve original events.")
                    .foregroundStyle(TraceColor.textSecondary)

                Picker("Project", selection: $selectedProjectId) {
                    ForEach(store.projects) { Text($0.displayName).tag($0.id) }
                }
                .frame(maxWidth: 320)

                if events.isEmpty {
                    Text("No memory events for this project yet.")
                        .traceCard(elevated: true)
                } else {
                    ForEach(events.reversed()) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(event.event_type ?? "event")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TraceColor.brand)
                                Spacer()
                                Text(event.created?.at ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(TraceColor.textSecondary)
                            }
                            if let location = event.what?.location {
                                Text(location)
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            if let why = event.why {
                                Text(why)
                                    .font(.system(size: 13))
                                    .foregroundStyle(TraceColor.textSecondary)
                            }
                            if let claim = event.claim {
                                Label("Inferred: \(claim)", systemImage: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(TraceColor.review)
                            }
                            HStack {
                                OriginBadge(origin: .skill)
                                if let harness = event.agent?.harness {
                                    Text(harness).font(.caption2).foregroundStyle(TraceColor.textSecondary)
                                }
                                if let eid = event.evidence_ids, !eid.isEmpty {
                                    Text("evidence: \(eid.joined(separator: ", "))")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(TraceColor.textSecondary)
                                }
                            }
                        }
                        .traceCard()
                    }
                }

                Button {
                    model.openAsk(projectId: selectedProjectId.isEmpty ? projectId : selectedProjectId, itemId: nil)
                } label: {
                    Label("Ask with this project", systemImage: TraceSymbol.ask)
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .background(TraceColor.canvas)
        .onAppear {
            selectedProjectId = projectId ?? store.projects.first?.id ?? ""
        }
    }
}
