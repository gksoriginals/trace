import SwiftUI
import AppKit

/// Prism / Ink tokens from docs/design.md.
enum TraceColor {
    static let canvas = Color(light: "F5F3FF", dark: "14131D")
    static let surface = Color(light: "FFFFFF", dark: "1D1B2B")
    static let elevated = Color(light: "EEEBF8", dark: "262238")
    static let textPrimary = Color(light: "202033", dark: "F4F1FF")
    static let textSecondary = Color(light: "626075", dark: "B8B2C9")
    static let line = Color(light: "8B849F", dark: "837A9A")
    static let brand = Color(light: "6D42C5", dark: "B99BFF")
    static let onBrand = Color(light: "FFFFFF", dark: "191322")
    static let focus = Color(light: "8054D5", dark: "D3BEFF")
    static let safe = Color(light: "16714E", dark: "68D5A5")
    static let review = Color(light: "945B00", dark: "F1C56B")
    static let critical = Color(light: "B43C53", dark: "FF98AD")
    static let freed = Color(light: "006C86", dark: "6DD7F0")
    static let caches = Color(light: "776005", dark: "E7CF70")
    static let builds = Color(light: "3560B8", dark: "92B6FF")
    static let worktrees = Color(light: "8050A7", dark: "CEABF5")
    static let containers = Color(light: "087780", dark: "70D3DD")
    static let models = Color(light: "A24178", dark: "F3A0CC")
}

private extension Color {
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: darkMode ? dark : light)
        }))
    }
}

private extension NSColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct TraceCardModifier: ViewModifier {
    var elevated = false
    var selected = false
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(elevated ? TraceColor.elevated : TraceColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? TraceColor.brand : TraceColor.line.opacity(0.35), lineWidth: selected ? 2 : 1)
            )
    }
}

extension View {
    func traceCard(elevated: Bool = false, selected: Bool = false) -> some View {
        modifier(TraceCardModifier(elevated: elevated, selected: selected))
    }
}

enum TraceSymbol {
    static let home = "house"
    static let setup = "slider.horizontal.3"
    static let ask = "magnifyingglass"
    static let run = "play.circle"
    static let memory = "books.vertical"
    static let settings = "gearshape"
    static let decideLater = "diamond"
    static let protected = "lock.fill"
    static let safe = "checkmark.circle"
    static let review = "exclamationmark.triangle"
    static let caches = "square.stack.3d.up"
    static let builds = "hammer"
    static let worktrees = "arrow.triangle.branch"
    static let containers = "shippingbox"
    static let models = "cube.transparent"
    static let data = "externaldrive"
    static let trash = "trash"
    static let undo = "arrow.uturn.backward"
    static let stop = "stop.circle"
    static let menuMark = "point.topleft.down.to.point.bottomright.curvepath"
}

/// Original Trace mark (asset catalog). Used in chrome / Setup / menu bar.
struct TraceMark: View {
    var size: CGFloat = 28
    var body: some View {
        Image("TraceMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel("Trace")
    }
}

/// Official marks: text name + neutral glyph until vendor assets are cleared (design.md §9).
struct AgentBadge: View {
    let kind: AgentKind
    var compact = false
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(TraceColor.elevated)
                    .frame(width: compact ? 24 : 36, height: compact ? 24 : 36)
                Image(systemName: glyph)
                    .font(.system(size: compact ? 11 : 14, weight: .semibold))
                    .foregroundStyle(TraceColor.brand)
            }
            if !compact {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TraceColor.textPrimary)
                    Text(kind.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(TraceColor.textSecondary)
                }
            } else {
                Text(kind.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TraceColor.textPrimary)
            }
        }
        .accessibilityLabel("\(kind.title) agent")
    }

    private var glyph: String {
        switch kind {
        case .cursor: return "cursorarrow.rays"
        case .codex: return "terminal"
        }
    }
}

extension AgentKind {
    var subtitle: String {
        switch self {
        case .cursor: return "ACP · first adapter"
        case .codex: return "app-server · first adapter"
        }
    }
}

struct OriginBadge: View {
    enum Origin: String { case skill = "Skill", app = "App run", user = "You" }
    let origin: Origin
    var body: some View {
        Text(origin.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TraceColor.elevated)
            .foregroundStyle(TraceColor.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct SafetyBadge: View {
    let state: ActionCard.SafetyState
    var body: some View {
        Label(label, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }
    private var label: String {
        switch state {
        case .verifiedDisposable: return "Verified disposable"
        case .needsReview: return "Needs review"
        case .protected: return "Protected"
        case .shared: return "Shared"
        case .unknown: return "Unknown"
        }
    }
    private var icon: String {
        switch state {
        case .verifiedDisposable: return TraceSymbol.safe
        case .needsReview: return TraceSymbol.review
        case .protected: return TraceSymbol.protected
        case .shared: return "person.2"
        case .unknown: return "questionmark.circle"
        }
    }
    private var color: Color {
        switch state {
        case .verifiedDisposable: return TraceColor.safe
        case .needsReview: return TraceColor.review
        case .protected: return TraceColor.critical
        case .shared: return TraceColor.review
        case .unknown: return TraceColor.textSecondary
        }
    }
}
