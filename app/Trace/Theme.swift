import SwiftUI

/// Prism / Ink tokens from docs/design.md — role names, not one-off colours.
enum TraceTheme {
    static let canvasLight = Color(red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xFF / 255)
    static let canvasDark = Color(red: 0x14 / 255, green: 0x13 / 255, blue: 0x1D / 255)
    static let surfaceLight = Color.white
    static let surfaceDark = Color(red: 0x1D / 255, green: 0x1B / 255, blue: 0x2B / 255)
    static let brandLight = Color(red: 0x6D / 255, green: 0x42 / 255, blue: 0xC5 / 255)
    static let brandDark = Color(red: 0xB9 / 255, green: 0x9B / 255, blue: 0xFF / 255)
    static let reviewLight = Color(red: 0x94 / 255, green: 0x5B / 255, blue: 0x00 / 255)
    static let textSecondaryLight = Color(red: 0x62 / 255, green: 0x60 / 255, blue: 0x75 / 255)

    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? canvasDark : canvasLight
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceDark : surfaceLight
    }

    static func brand(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? brandDark : brandLight
    }
}
