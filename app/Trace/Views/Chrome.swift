import SwiftUI

struct AppChrome: View {
    @ObservedObject var model: AppModel
    let content: AnyView
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            VStack(spacing: 0) {
                topBar
                Divider().overlay(TraceColor.line.opacity(0.35))
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TraceColor.canvas)
            }
            .background(TraceColor.canvas)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(TraceColor.brand)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: TraceSpace.xs) {
            HStack(spacing: TraceSpace.sm) {
                TraceMark(size: 22)
                Text("Trace")
                    .font(TraceType.bodyMedium)
                    .foregroundStyle(TraceColor.textPrimary)
            }
            .padding(.horizontal, TraceSpace.lg)
            .padding(.top, TraceSpace.xl)
            .padding(.bottom, TraceSpace.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Trace")

            sidebarItem("Home", TraceSymbol.home, .home)
            sidebarItem("Ask Trace", TraceSymbol.ask, .ask(projectId: nil, itemId: nil))
            sidebarItem("Memory", TraceSymbol.memory, .memory(nil))
            sidebarItem("Setup", TraceSymbol.setup, .setup)
            sidebarItem("Settings", TraceSymbol.settings, .settings)

            Spacer(minLength: 0)

            if model.supervisor.isBusy {
                HStack(spacing: TraceSpace.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(model.supervisor.pendingPermission != nil ? "Needs your answer" : "Agent working")
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.review)
                        .lineLimit(2)
                }
                .padding(TraceSpace.lg)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(model.supervisor.pendingPermission != nil ? "Agent needs your answer" : "Agent working")
            }
        }
        .padding(.bottom, TraceSpace.sm)
        .background(TraceColor.elevated)
    }

    private func sidebarItem(_ title: String, _ symbol: String, _ dest: AppModel.Destination) -> some View {
        let selected = isSelected(dest)
        return Button {
            model.destination = dest
        } label: {
            HStack(spacing: TraceSpace.md) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(selected ? TraceColor.brand : Color.clear)
                    .frame(width: 3, height: 18)
                Label(title, systemImage: symbol)
                    .font(TraceType.body)
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? TraceColor.brand : TraceColor.textPrimary)
            .padding(.vertical, 8)
            .padding(.trailing, TraceSpace.lg)
            .padding(.leading, TraceSpace.sm)
            .frame(maxWidth: .infinity, minHeight: TraceSpace.hit, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? TraceColor.surface : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, TraceSpace.sm)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func isSelected(_ dest: AppModel.Destination) -> Bool {
        switch (model.destination, dest) {
        case (.home, .home), (.setup, .setup), (.settings, .settings): return true
        case (.ask, .ask): return true
        case (.memory, .memory): return true
        case (.decideLater, .home), (.run, .home), (.result, .home), (.recovery, .home): return false
        default: return false
        }
    }

    private var topBar: some View {
        HStack(spacing: TraceSpace.md) {
            Text(breadcrumb)
                .font(TraceType.bodyMedium)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                model.openAsk(projectId: nil, itemId: nil)
            } label: {
                Label("Ask Trace", systemImage: TraceSymbol.ask)
            }
            .buttonStyle(.borderedProminent)
            .tint(TraceColor.brand)
            .keyboardShortcut("k", modifiers: .command)
            .help("Ask Trace (⌘K)")
            .accessibilityHint("Opens memory-first Ask")
        }
        .padding(.horizontal, TraceSpace.windowPad)
        .padding(.vertical, TraceSpace.md)
        .background(TraceColor.surface)
    }

    private var breadcrumb: String {
        switch model.destination {
        case .home: return "Home"
        case .setup: return "Setup"
        case .settings: return "Settings"
        case .ask: return "Ask Trace"
        case .run(let scope): return "Run · \(scope.title)"
        case .decideLater: return "Home / Decide later"
        case .result: return "Run / Result"
        case .recovery: return "Run / Recovery"
        case .memory: return "Memory"
        }
    }
}
