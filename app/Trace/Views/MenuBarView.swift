import SwiftUI

/// S15 Menu bar companion — short status + open full app. Never one-click clean.
struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TraceMark(size: 20)
                Text("Trace")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            Text(model.menuStatusLine)
                .font(.system(size: 12))
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(2)

            if model.menuQueueCount > 0 {
                Label("\(model.menuQueueCount) Decide later", systemImage: TraceSymbol.decideLater)
                    .font(.caption)
                    .foregroundStyle(TraceColor.review)
            }

            if model.supervisor.isBusy {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(model.supervisor.status)
                        .font(.caption)
                        .foregroundStyle(TraceColor.textSecondary)
                }
            }

            Divider()

            Button("Open Trace") {
                model.openMain(to: .home)
            }
            .keyboardShortcut("o")

            Button("Ask Trace…") {
                model.openAsk(projectId: nil, itemId: nil)
            }
            .keyboardShortcut("k")

            if model.supervisor.isBusy {
                Button("Stop") {
                    Task { await model.supervisor.cancel() }
                }
            }

            Button("Settings…") {
                model.openMain(to: .settings)
            }

            Divider()

            Button("Quit Trace") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }
}
