import SwiftUI

/// S15 Menu bar companion — short status + open full app. Never one-click clean.
struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.md) {
            HStack(spacing: TraceSpace.sm) {
                TraceMark(size: 18)
                Text("Trace")
                    .font(TraceType.bodyMedium)
                    .foregroundStyle(TraceColor.textPrimary)
                Spacer(minLength: 0)
            }

            Text(model.menuStatusLine)
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if model.menuQueueCount > 0 {
                Label("\(model.menuQueueCount) Decide later", systemImage: TraceSymbol.decideLater)
                    .font(TraceType.caption)
                    .foregroundStyle(TraceColor.review)
            }

            if model.supervisor.isBusy {
                HStack(spacing: TraceSpace.sm) {
                    ProgressView().controlSize(.small)
                    Text(model.supervisor.status)
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.textSecondary)
                        .lineLimit(1)
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

            // Run (per project / all permitted) only from the main window — never from this popover.

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
        .padding(TraceSpace.md)
        .frame(width: 280)
        .background(TraceColor.surface)
    }
}
