import SwiftUI

/// S6 Decide-later detail — local Keep/Defer; Ask opens S13; Plan action is not Execute consent.
struct DecideLaterView: View {
    @ObservedObject var model: AppModel
    let itemId: String

    private var item: DecideLaterItem? {
        model.store.decideLater.first { $0.id == itemId }
            ?? model.store.decideLater.first { $0.id == itemId } // refresh may drop resolved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button {
                        model.destination = .decideLaterQueue
                    } label: {
                        Label("Decide later", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                if let item {
                    content(item)
                } else {
                    Text("This Decide-later item is no longer open.")
                        .foregroundStyle(TraceColor.textSecondary)
                        .traceCard()
                    Button("Back to queue") { model.destination = .decideLaterQueue }
                }
            }
            .tracePageColumn(maxWidth: 720)
        }
        .background(TraceColor.canvas)
    }

    private func content(_ item: DecideLaterItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: TraceSymbol.decideLater)
                    .foregroundStyle(TraceColor.review)
                Text("Decide later")
                    .font(.system(size: 28, weight: .semibold))
            }
            Text(item.action ?? item.artifact_id ?? item.id)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TraceColor.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                labeled("Why doubtful", item.why_doubtful ?? "—")
                labeled("Would resolve", item.would_resolve ?? "—")
                labeled("Status", item.status ?? "open")
                labeled("Project", item.project_id ?? "—")
                labeled("Agent", item.agent ?? "—")
                if let bytes = item.bytes {
                    labeled("Bytes (reported)", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                }
                labeled("Completeness", item.completeness ?? "—")
                labeled("First observed", item.first_observed ?? "—")
                labeled("Last observed", item.last_observed ?? "—")
                if let evidence = item.evidence_ids, !evidence.isEmpty {
                    labeled("Evidence", evidence.joined(separator: ", "))
                }
            }
            .traceCard()

            HStack {
                if let project = model.store.projects.first(where: { $0.id == item.project_id }) {
                    Button("Plan action") {
                        Task {
                            model.destination = .decideLaterQueue
                            await model.runInPlace(.project(project))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                    .disabled(model.supervisor.isBusy)
                }
                Button("Keep this time") {
                    model.store.updateQueueStatus(id: item.id, status: "kept")
                    model.destination = .decideLaterQueue
                }
                Button("Defer") {
                    model.store.updateQueueStatus(id: item.id, status: "deferred")
                    model.destination = .decideLaterQueue
                }
                Button {
                    model.openAsk(projectId: item.project_id, itemId: item.id)
                } label: {
                    Label("Ask", systemImage: TraceSymbol.ask)
                }
            }

            Text("Plan action is not consent to clean. S8 still owns selection and Trash. Keep and Defer are local — no agent call.")
                .font(.caption)
                .foregroundStyle(TraceColor.textSecondary)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(TraceColor.textSecondary)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(TraceColor.textPrimary)
                .textSelection(.enabled)
        }
    }
}
