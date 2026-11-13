import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if !model.store.hasCompletedSetup || model.destination == .setup {
                // Full Setup without chrome so the 4-step wizard owns the window.
                SetupView(model: model)
            } else {
                AppChrome(model: model, content: AnyView(destinationView))
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .preferredColorScheme(colorScheme)
        .onChange(of: model.store.settings.backgroundReviewEnabled) { _, _ in
            model.background.restart()
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch model.destination {
        case .setup:
            SetupView(model: model)
        case .home:
            HomeView(model: model)
        case .decideLaterQueue:
            DecideLaterQueueView(model: model)
        case .decideLaterItem(let id):
            DecideLaterView(model: model, itemId: id)
        case .ask(let projectId, let itemId):
            // Legacy destination — open floating Ask and stay on Home.
            Color.clear
                .onAppear {
                    model.openAsk(projectId: projectId, itemId: itemId)
                    model.destination = .home
                }
        case .run(let scope):
            RunView(model: model, scope: scope)
        case .result:
            ResultView(model: model)
        case .recovery:
            RecoveryView(model: model)
        case .memory(let projectId):
            MemoryView(model: model, projectId: projectId)
        case .history:
            HistoryView(model: model)
        case .settings:
            SettingsView(model: model)
        }
    }

    private var colorScheme: ColorScheme? {
        switch model.store.settings.appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
