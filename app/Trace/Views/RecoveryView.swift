import SwiftUI
import AppKit

/// S11 Recovery — exact journaled Trash items; Restore once; no overwrite.
struct RecoveryView: View {
    @ObservedObject var model: AppModel
    @State private var selected: Set<String> = []
    @State private var message = ""

    private var store: TraceStore { model.store }

    private var movable: [JournalEntry] {
        store.journal.filter { $0.outcome == "moved" && ($0.trashDestination?.isEmpty == false) }
            .reversed()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button { model.destination = .home } label: {
                        Label("Home", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Text("Recovery")
                    .font(.system(size: 28, weight: .semibold))
                Text("Exact journaled Trash destinations. Restore does not overwrite an occupied path.")
                    .foregroundStyle(TraceColor.textSecondary)

                if movable.isEmpty {
                    Text("No moved items in the journal yet.")
                        .traceCard(elevated: true)
                } else {
                    ForEach(movable) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { selected.contains(entry.id) },
                                set: { on in
                                    if on { selected.insert(entry.id) } else { selected.remove(entry.id) }
                                }
                            ))
                            .labelsHidden()
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.path)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                Text("Trash: \(entry.trashDestination ?? "—")")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(TraceColor.textSecondary)
                                Text("At \(entry.at) · fingerprint \(entry.fingerprintBeforeMove ?? "—")")
                                    .font(.caption2)
                                    .foregroundStyle(TraceColor.textSecondary)
                            }
                            Spacer()
                            Button("Reveal") {
                                if let trash = entry.trashDestination {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: trash)])
                                }
                            }
                        }
                        .traceCard(selected: selected.contains(entry.id))
                    }
                }

                HStack {
                    Button {
                        restoreSelected()
                    } label: {
                        Label("Restore \(selected.count) selected", systemImage: TraceSymbol.undo)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                    .disabled(selected.isEmpty)

                    Button("Back") { model.destination = .result }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(TraceColor.review)
                }
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .background(TraceColor.canvas)
    }

    private func restoreSelected() {
        var ok = 0
        var fail = 0
        for entry in movable where selected.contains(entry.id) {
            if TrashService.undo(entry: entry) == nil {
                ok += 1
            } else {
                fail += 1
            }
        }
        store.refresh()
        selected.removeAll()
        message = "Restored \(ok). Conflicts or missing Trash sources: \(fail). Occupied destinations stay explicit."
    }
}
