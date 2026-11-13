import SwiftUI
import AppKit

@main
struct TraceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
        }
        .defaultSize(width: 1080, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Trace") {
                Button("Ask Trace") {
                    model.openAsk(projectId: nil, itemId: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("Home") {
                    model.openMain(to: .home)
                }
                Button("Settings…") {
                    model.openMain(to: .settings)
                }
                Divider()
                Button("Stop agent") {
                    Task { await model.supervisor.cancel() }
                }
            }
        }

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 480, minHeight: 420)
        }
    }
}
