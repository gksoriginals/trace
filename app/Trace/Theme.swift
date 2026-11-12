import SwiftUI

/// Prism / Ink — role tokens from docs/design.md §2.
enum TraceTheme {
    static func canvas(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.08, green: 0.07, blue: 0.11) : Color(red: 0.96, green: 0.95, blue: 1.0)
    }
    static func surface(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.11, green: 0.11, blue: 0.17) : .white
    }
    static func elevated(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.15, green: 0.13, blue: 0.22) : Color(red: 0.93, green: 0.92, blue: 0.97)
    }
    static func brand(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.73, green: 0.61, blue: 1.0) : Color(red: 0.43, green: 0.26, blue: 0.77)
    }
    static func review(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.95, green: 0.77, blue: 0.42) : Color(red: 0.58, green: 0.36, blue: 0.0)
    }
    static func safe(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.41, green: 0.84, blue: 0.65) : Color(red: 0.09, green: 0.44, blue: 0.31)
    }
    static let secondaryText = Color.secondary
}
