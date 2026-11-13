import SwiftUI

/// Content + narrow right icon rail. Destinations first, then actions, Ask at the bottom.
struct AppChrome: View {
    @ObservedObject var model: AppModel
    let content: AnyView

    private let railWidth: CGFloat = 56

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TraceColor.canvas)
                    .padding(.top, 28)

                Rectangle()
                    .fill(TraceColor.line.opacity(0.35))
                    .frame(width: 1)

                rightRail
                    .frame(width: railWidth)
                    .frame(maxHeight: .infinity)
                    .background(TraceColor.surface)
            }

            if model.showAskPanel {
                AskFloatingPanel(model: model)
                    .padding(.trailing, railWidth + TraceSpace.md)
                    .padding(.bottom, TraceSpace.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .background(TraceColor.canvas)
        .tint(TraceColor.brand)
        .animation(.easeInOut(duration: 0.16), value: model.showAskPanel)
    }

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    private var rightRail: some View {
        VStack(spacing: TraceSpace.sm) {
            Color.clear
                .frame(height: TraceSpace.md)
                .accessibilityHidden(true)

            // Destinations — project memory/history live on Home cards, not a separate rail icon.
            railIcon(title: "Home", symbol: TraceSymbol.home, selected: isHomeSelected) {
                model.destination = .home
            }
            decideLaterButton
            railIcon(title: "History", symbol: TraceSymbol.history, selected: isHistorySelected) {
                model.destination = .history
            }
            railIcon(title: "Settings", symbol: TraceSymbol.settings, selected: isSettingsSelected) {
                model.destination = .settings
            }

            Spacer(minLength: TraceSpace.md)

            if supervisor.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .help(supervisor.pendingPermission != nil ? "Needs your answer" : "Agent working")
                    .accessibilityLabel(supervisor.pendingPermission != nil ? "Needs your answer" : "Agent working")
            }

            // Actions
            railIcon(title: "Refresh", symbol: "arrow.clockwise", selected: false) {
                store.refresh()
            }

            Button {
                Task { await model.runInPlace(.allPermitted) }
            } label: {
                Group {
                    if supervisor.isBusy {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: TraceSymbol.run)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TraceColor.onBrand)
                .frame(width: TraceSpace.hit, height: TraceSpace.hit)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TraceColor.brand)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.projects.isEmpty || supervisor.isBusy)
            .help("Run — review permitted projects")
            .accessibilityLabel("Run")

            askChatButton
        }
        .padding(.vertical, TraceSpace.md)
        .frame(maxWidth: .infinity)
    }

    private var askChatButton: some View {
        Button {
            if model.showAskPanel {
                model.closeAskPanel()
            } else {
                model.openAsk(projectId: nil, itemId: nil)
            }
        } label: {
            Image(systemName: TraceSymbol.ask)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(model.showAskPanel ? TraceColor.onBrand : TraceColor.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(model.showAskPanel ? TraceColor.brand : TraceColor.elevated)
                )
                .overlay(
                    Circle()
                        .stroke(TraceColor.brand.opacity(model.showAskPanel ? 0 : 0.45), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .help(model.showAskPanel ? "Close Ask" : "Ask Trace")
        .accessibilityLabel(model.showAskPanel ? "Close Ask" : "Ask Trace")
        .accessibilityAddTraits(model.showAskPanel ? .isSelected : [])
        .padding(.top, TraceSpace.xs)
    }

    private func railIcon(title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? TraceColor.brand : TraceColor.textPrimary)
                .frame(width: TraceSpace.hit, height: TraceSpace.hit)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? TraceColor.elevated : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var openDecideLaterCount: Int { model.store.decideLater.count }

    private var isDecideLaterSelected: Bool {
        switch model.destination {
        case .decideLaterQueue, .decideLaterItem: return true
        default: return false
        }
    }

    /// Decide later — diamond queue icon with open-count badge; opens its own surface.
    private var decideLaterButton: some View {
        Button {
            model.destination = .decideLaterQueue
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: TraceSymbol.decideLater)
                    .font(.system(size: 14, weight: isDecideLaterSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isDecideLaterSelected || openDecideLaterCount > 0
                            ? TraceColor.review
                            : TraceColor.textPrimary
                    )
                    .frame(width: TraceSpace.hit, height: TraceSpace.hit)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isDecideLaterSelected ? TraceColor.elevated : Color.clear)
                    )
                if openDecideLaterCount > 0 {
                    Text(openDecideLaterCount > 99 ? "99+" : "\(openDecideLaterCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, openDecideLaterCount > 9 ? 3 : 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(TraceColor.critical))
                        .offset(x: 6, y: -4)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(openDecideLaterCount == 0
              ? "Decide later — nothing waiting"
              : "Decide later — \(openDecideLaterCount) open")
        .accessibilityLabel(
            openDecideLaterCount == 0
                ? "Decide later, nothing waiting"
                : "Decide later, \(openDecideLaterCount) open"
        )
        .accessibilityAddTraits(isDecideLaterSelected ? .isSelected : [])
    }

    private var isHomeSelected: Bool {
        switch model.destination {
        case .home, .memory, .run, .result, .recovery: return true
        default: return false
        }
    }

    private var isHistorySelected: Bool {
        model.destination == .history
    }

    private var isSettingsSelected: Bool {
        model.destination == .settings
    }
}
