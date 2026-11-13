import SwiftUI

/// S12 Memory / Learnings — index first, detail on demand; facts vs inferred.
struct MemoryView: View {
    @ObservedObject var model: AppModel
    var projectId: String?

    @State private var selectedProjectId: String = ""
    @State private var selectedEventId: String?

    private var store: TraceStore { model.store }

    private var activeProjectId: String {
        if !selectedProjectId.isEmpty { return selectedProjectId }
        return projectId ?? store.projects.first?.id ?? ""
    }

    private var events: [MemoryEvent] {
        store.events(for: activeProjectId).reversed()
    }

    private var selectedEvent: MemoryEvent? {
        if let selectedEventId {
            return events.first { $0.id == selectedEventId }
        }
        return events.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Memory")
                    .font(TraceType.screen)
                Spacer()
                Picker("Project", selection: $selectedProjectId) {
                    ForEach(store.projects) { Text($0.displayName).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                .onChange(of: selectedProjectId) { _, _ in selectedEventId = nil }
            }
            .padding(.horizontal, TraceSpace.windowPad)
            .padding(.vertical, TraceSpace.md)
            .background(TraceColor.surface)

            Divider().overlay(TraceColor.line.opacity(0.35))

            if events.isEmpty {
                Text("No memory events for this project yet.")
                    .foregroundStyle(TraceColor.textSecondary)
                    .padding(TraceSpace.xxl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    indexPane
                        .frame(width: 280)
                    Divider().overlay(TraceColor.line.opacity(0.35))
                    detailPane
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(TraceColor.canvas)
        .onAppear {
            if selectedProjectId.isEmpty {
                selectedProjectId = projectId ?? store.projects.first?.id ?? ""
            }
        }
    }

    private var indexPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraceSpace.sm) {
                Text("Index")
                    .font(TraceType.section)
                    .padding(.bottom, 4)
                ForEach(events) { event in
                    let on = (selectedEventId ?? events.first?.id) == event.id
                    Button {
                        selectedEventId = event.id
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(indexTitle(event))
                                .font(TraceType.bodyMedium)
                                .foregroundStyle(TraceColor.textPrimary)
                                .lineLimit(2)
                            Text(indexKind(event))
                                .font(TraceType.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(on ? TraceColor.elevated : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(TraceSpace.lg)
        }
        .background(TraceColor.surface)
    }

    private var detailPane: some View {
        ScrollView {
            if let event = selectedEvent {
                VStack(alignment: .leading, spacing: TraceSpace.md) {
                    Text(indexTitle(event))
                        .font(TraceType.screen)
                    Text("\(indexKind(event)) · \(event.created?.at ?? "unknown time")")
                        .font(TraceType.meta)
                        .foregroundStyle(TraceColor.textSecondary)
                    if let location = event.what?.location {
                        Text(location)
                            .font(TraceType.path)
                            .textSelection(.enabled)
                    }
                    if let why = event.why {
                        Text(why)
                            .font(TraceType.body)
                            .foregroundStyle(TraceColor.textPrimary)
                    }
                    if let claim = event.claim {
                        Label("Inferred: \(claim)", systemImage: "sparkles")
                            .font(TraceType.meta)
                            .foregroundStyle(TraceColor.review)
                    }
                    HStack(spacing: TraceSpace.sm) {
                        OriginBadge(origin: .skill)
                        if let harness = event.agent?.harness {
                            Text(harness).font(TraceType.caption).foregroundStyle(TraceColor.textSecondary)
                        }
                    }
                    if let eid = event.evidence_ids, !eid.isEmpty {
                        Text("Source: \(eid.joined(separator: ", "))")
                            .font(TraceType.path)
                            .foregroundStyle(TraceColor.brand)
                    }
                    HStack {
                        Button {
                            model.openAsk(projectId: activeProjectId, itemId: nil)
                        } label: {
                            Label("Ask with project", systemImage: TraceSymbol.ask)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TraceColor.brand)
                    }
                    .padding(.top, TraceSpace.sm)
                }
                .padding(TraceSpace.xl)
                .frame(maxWidth: 720, alignment: .leading)
            }
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
}
