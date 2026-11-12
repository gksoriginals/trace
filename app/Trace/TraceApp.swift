import AppKit
import SwiftUI

@main
struct TraceApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("Trace") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 840, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 740)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Setup…") {
                    store.route = .setup
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Ask") {
                Button("Ask Trace") {
                    NotificationCenter.default.post(name: .traceOpenAsk, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        MenuBarExtra("Trace", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            Button("Open Trace") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApplication.shared.windows where window.title == "Trace" {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Button("Ask Trace") {
                NotificationCenter.default.post(name: .traceOpenAsk, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Setup…") { store.route = .setup }
            Divider()
            Button("Quit Trace") { NSApp.terminate(nil) }
        }
    }
}

extension Notification.Name {
    static let traceOpenAsk = Notification.Name("traceOpenAsk")
}
