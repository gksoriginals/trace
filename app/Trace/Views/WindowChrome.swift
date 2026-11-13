import SwiftUI
import AppKit

/// Merges the system title bar into Trace chrome: traffic lights sit over the canvas,
/// with no separate black title strip.
struct UnifiedTitleBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WindowChromeConfigurator())
    }
}

extension View {
    func unifiedTitleBar() -> some View {
        modifier(UnifiedTitleBar())
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        DispatchQueue.main.async { Self.apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.apply(to: nsView.window) }
    }

    private static func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        // Transparent title bars otherwise fall back to a black system strip.
        window.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(srgbRed: dark ? 0x14 / 255 : 0xF5 / 255,
                           green: dark ? 0x13 / 255 : 0xF3 / 255,
                           blue: dark ? 0x1D / 255 : 0xFF / 255,
                           alpha: 1)
        })
    }
}
