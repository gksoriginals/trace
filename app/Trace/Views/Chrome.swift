import SwiftUI

struct AppChrome: View {
    @ObservedObject var model: AppModel
    let content: AnyView

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
                .background(TraceColor.elevated)
            Divider().background(TraceColor.line)
            VStack(spacing: 0) {
                topBar
                Divider().background(TraceColor.line)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TraceColor.canvas)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TraceMark(size: 24)
                Text("Trace")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TraceColor.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            nav(title: "Home", symbol: TraceSymbol.home, dest: .home)
            nav(title: "Ask Trace", symbol: TraceSymbol.ask, dest: .ask(projectId: nil, itemId: nil))
            nav(title: "Memory", symbol: TraceSymbol.memory, dest: .memory(nil))
            nav(title: "Setup", symbol: TraceSymbol.setup, dest: .setup)
            nav(title: "Settings", symbol: TraceSymbol.settings, dest: .settings)

            Spacer()
            if model.supervisor.isBusy {
                Label("Agent working", systemImage: TraceSymbol.run)
                    .font(.caption)
                    .foregroundStyle(TraceColor.review)
                    .padding(16)
            }
        }
        .padding(.vertical, 8)
    }

    private func nav(title: String, symbol: String, dest: AppModel.Destination) -> some View {
        Button {
            model.destination = dest
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected(dest) ? TraceColor.surface : Color.clear)
                .foregroundStyle(isSelected(dest) ? TraceColor.brand : TraceColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func isSelected(_ dest: AppModel.Destination) -> Bool {
        switch (model.destination, dest) {
        case (.home, .home), (.setup, .setup), (.settings, .settings): return true
        case (.ask, .ask): return true
        case (.memory, .memory): return true
        default: return false
        }
    }

    private var topBar: some View {
        HStack {
            Text(breadcrumb)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TraceColor.textSecondary)
            Spacer()
            Button {
                model.openAsk(projectId: nil, itemId: nil)
            } label: {
                Label("Ask Trace", systemImage: TraceSymbol.ask)
            }
            .keyboardShortcut("k", modifiers: .command)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(TraceColor.surface)
    }

    private var breadcrumb: String {
        switch model.destination {
        case .home: return "Home"
        case .setup: return "Setup"
        case .settings: return "Settings"
        case .ask: return "Ask Trace"
        case .run(let p): return "Run · \(p.displayName)"
        case .decideLater: return "Decide later"
        case .result: return "Result"
        case .recovery: return "Recovery"
        case .memory: return "Memory"
        }
    }
}
