import SwiftUI

/// Top nav chrome matching Pen Home/Ask/Settings v2.
/// Trace mark is Home. Setup lives inside Settings / first-run only — not a primary nav item.
struct AppChrome: View {
    @ObservedObject var model: AppModel
    let content: AnyView

    var body: some View {
        VStack(spacing: 0) {
            topNav
            Rectangle()
                .fill(TraceColor.line.opacity(0.35))
                .frame(height: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TraceColor.canvas)
        }
        .background(TraceColor.canvas)
        .tint(TraceColor.brand)
    }

    private var topNav: some View {
        HStack(spacing: TraceSpace.md) {
            Button {
                model.destination = .home
            } label: {
                HStack(spacing: TraceSpace.sm) {
                    TraceMark(size: 22)
                    Text("Trace")
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trace Home")
            .accessibilityAddTraits(isHomeSelected ? .isSelected : [])

            Spacer(minLength: TraceSpace.lg)

            HStack(spacing: TraceSpace.xs) {
                navLink("Home", .home, isHomeSelected)
                navLink("Ask", .ask(projectId: nil, itemId: nil), isAskSelected)
                    .keyboardShortcut("k", modifiers: .command)
                navLink("Memory", .memory(nil), isMemorySelected)
                navLink("Settings", .settings, isSettingsSelected)
            }

            if model.supervisor.isBusy {
                HStack(spacing: TraceSpace.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(model.supervisor.pendingPermission != nil ? "Needs your answer" : "Agent working")
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.review)
                        .lineLimit(1)
                }
                .padding(.leading, TraceSpace.sm)
            }
        }
        .padding(.horizontal, TraceSpace.windowPad)
        .padding(.vertical, TraceSpace.md)
        .background(TraceColor.surface)
    }

    private func navLink(_ title: String, _ dest: AppModel.Destination, _ selected: Bool) -> some View {
        Button {
            model.destination = dest
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? TraceColor.brand : TraceColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? TraceColor.elevated : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var isHomeSelected: Bool {
        switch model.destination {
        case .home, .decideLater, .run, .result, .recovery: return true
        default: return false
        }
    }

    private var isAskSelected: Bool {
        if case .ask = model.destination { return true }
        return false
    }

    private var isMemorySelected: Bool {
        if case .memory = model.destination { return true }
        return false
    }

    private var isSettingsSelected: Bool {
        model.destination == .settings
    }
}
