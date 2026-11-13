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

/// Design.md type scale — SF Pro + SF Mono.
enum TraceType {
    static let outcome = Font.system(size: 28, weight: .semibold).monospacedDigit()
    static let screen = Font.system(size: 20, weight: .semibold)
    static let section = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let path = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let meta = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 11, weight: .medium)
}

enum TraceSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let windowPad: CGFloat = 24
    /// Leading inset so nav content clears native traffic lights in a unified title bar.
    static let trafficLights: CGFloat = 78
    static let contentMax: CGFloat = 960
    static let hit: CGFloat = 28
    static let radius: CGFloat = 8
    static let inspector: CGFloat = 320
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
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .padding(compact ? TraceSpace.sm : TraceSpace.lg)
            .padding(.horizontal, compact ? TraceSpace.md : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                    .fill(elevated ? TraceColor.elevated : TraceColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                    .stroke(selected ? TraceColor.brand : TraceColor.line.opacity(0.35), lineWidth: selected ? 2 : 1)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.14), value: selected)
    }
}

extension View {
    func traceCard(elevated: Bool = false, selected: Bool = false, compact: Bool = false) -> some View {
        modifier(TraceCardModifier(elevated: elevated, selected: selected, compact: compact))
    }

    /// Full-width page body inside a ScrollView. Default fills the window (window pad only)
    /// so wide macOS windows do not leave an empty right gutter.
    func tracePageColumn(maxWidth: CGFloat = .infinity) -> some View {
        self
            .padding(TraceSpace.windowPad)
            .frame(maxWidth: maxWidth == .infinity ? .infinity : maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func traceFocusRing() -> some View {
        self.focusable()
            .focusEffectDisabled(false)
    }
}

enum TraceSymbol {
    static let home = "house"
    static let setup = "slider.horizontal.3"
    static let ask = "bubble.left.and.bubble.right"
    static let run = "play.circle"
    static let memory = "books.vertical"
    static let history = "clock.arrow.circlepath"
    static let settings = "gearshape"
    /// Uncertain leftovers waiting for a decision — not a system notification bell.
    static let decideLater = "questionmark.diamond"
    static let addFolder = "plus"
    static let protected = "lock.fill"
    static let safe = "checkmark.circle"
    static let review = "questionmark.diamond"
    static let caches = "square.stack.3d.up"
    static let builds = "hammer"
    static let worktrees = "arrow.triangle.branch"
    static let containers = "shippingbox"
    static let models = "cube.transparent"
    static let data = "externaldrive"
    static let trash = "trash"
    static let undo = "arrow.uturn.backward"
    static let stop = "stop.circle"
}

struct TraceScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            Text(title)
                .font(TraceType.screen)
                .foregroundStyle(TraceColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// High-visibility status strip for dogfood — errors must not hide in scroll chrome.
struct TraceStatusBanner: View {
    enum Kind { case error, working, info }

    let kind: Kind
    let title: String
    let detail: String?
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            HStack(alignment: .top, spacing: TraceSpace.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(TraceType.path)
                            .foregroundStyle(TraceColor.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if primaryTitle != nil || secondaryTitle != nil {
                HStack(spacing: TraceSpace.sm) {
                    if let primaryTitle, let primaryAction {
                        Button(primaryTitle, action: primaryAction)
                            .buttonStyle(.borderedProminent)
                            .tint(kind == .error ? TraceColor.critical : TraceColor.brand)
                    }
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(TraceSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                .stroke(accent.opacity(0.55), lineWidth: 1.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(detail ?? "")")
    }

    private var icon: String {
        switch kind {
        case .error: return "exclamationmark.triangle.fill"
        case .working: return "arrow.triangle.2.circlepath"
        case .info: return "info.circle.fill"
        }
    }

    private var accent: Color {
        switch kind {
        case .error: return TraceColor.critical
        case .working: return TraceColor.review
        case .info: return TraceColor.brand
        }
    }

    private var fill: Color {
        switch kind {
        case .error: return TraceColor.critical.opacity(0.14)
        case .working: return TraceColor.review.opacity(0.12)
        case .info: return TraceColor.elevated
        }
    }
}

struct TraceSectionLabel: View {
    let title: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: TraceSpace.sm) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(TraceColor.brand)
                    .frame(width: 16, height: 16)
            }
            Text(title)
                .font(TraceType.section)
                .foregroundStyle(TraceColor.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Middle-elide long paths; full string remains for accessibility / copy.
struct PathLabel: View {
    let path: String
    var lineLimit: Int = 1
    var body: some View {
        Text(elided)
            .font(TraceType.path)
            .foregroundStyle(TraceColor.textSecondary)
            .lineLimit(lineLimit)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .help(path)
            .accessibilityLabel(path)
    }

    private var elided: String {
        guard path.count > 64 else { return path }
        let url = URL(fileURLWithPath: path)
        let tail = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent
        if parent.isEmpty { return "…/\(tail)" }
        return "…/\(parent)/\(tail)"
    }
}

/// 3 pt category leading mark per design.md — recognition, not safety.
struct CategoryLeadingMark: View {
    let category: StorageCategory
    var body: some View {
        HStack(spacing: TraceSpace.sm) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(category.accent)
                .frame(width: 3, height: 28)
            Image(systemName: category.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(category.accent)
                .frame(width: 18, height: 18)
        }
        .accessibilityLabel(category.title)
    }
}

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

struct AgentBadge: View {
    let kind: AgentKind
    var compact = false
    var body: some View {
        HStack(spacing: TraceSpace.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(TraceColor.elevated)
                    .frame(width: compact ? 22 : 32, height: compact ? 22 : 32)
                Image(systemName: glyph)
                    .font(.system(size: compact ? 10 : 13, weight: .semibold))
                    .foregroundStyle(TraceColor.brand)
            }
            if !compact {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(TraceType.bodyMedium)
                        .foregroundStyle(TraceColor.textPrimary)
                    Text(kind.subtitle)
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.textSecondary)
                }
            } else {
                Text(kind.title)
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
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
            .font(TraceType.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TraceColor.elevated)
            .foregroundStyle(TraceColor.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel("Origin \(origin.rawValue)")
    }
}

struct SafetyBadge: View {
    let state: ActionCard.SafetyState
    var body: some View {
        Label(label, systemImage: icon)
            .font(TraceType.caption)
            .foregroundStyle(color)
            .accessibilityLabel(label)
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

/// Quiet secondary control; primary stays `.borderedProminent` + brand tint at call site.
struct TraceToolbarButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(minHeight: TraceSpace.hit)
    }
}

/// Fixed-height page toolbar — keeps pickers/labels vertically centered (no floating controls).
struct TracePageBar<Leading: View, Trailing: View>: View {
    var height: CGFloat = 44
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: TraceSpace.md) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, TraceSpace.windowPad)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(TraceColor.canvas)
    }
}
