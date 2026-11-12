import AppKit
import SwiftUI

@main
struct TraceApp: App {
    @StateObject private var store = TraceStore()

    var body: some Scene {
        WindowGroup("Trace") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 840, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 740)

        Settings {
            SetupView()
                .environmentObject(store)
                .frame(width: 520, height: 480)
        }

        MenuBarExtra("Trace", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            Button("Open Trace") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.title == "Trace" {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Divider()
            Button("Quit Trace") { NSApp.terminate(nil) }
        }
    }
}
