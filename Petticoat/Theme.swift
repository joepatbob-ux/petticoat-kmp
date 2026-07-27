import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Design tokens pulled from the "SMA - iOS26" Figma file.
enum SMA {
    // Core palette — adaptive (light / dark), mapped to iOS system semantics.
    static let accent            = Color(light: 0x0088FF, dark: 0x0A84FF)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let background        = Color(uiColor: .systemBackground)
    static let card              = Color(uiColor: .secondarySystemGroupedBackground)
    static let labelPrimary      = Color(light: 0x000000, dark: 0xFFFFFF)
    static let labelSecondary    = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.6)
    static let separator         = Color(light: 0xE6E6E6, dark: 0x38383A)
    static let orange            = Color(hex: 0xF5A623)
    static let tempOrange        = Color(hex: 0xF16A1B)
    static let tempIdle          = Color(hex: 0x8E8E93)
    static let destructive       = Color(light: 0xFF3B30, dark: 0xFF453A)
    /// Offline / disconnected indicator (the Wi-Fi-off glyph on the dashboard).
    static let offlineRed        = Color(light: 0xE0392B, dark: 0xFF453A)
    static let fillTertiary      = Color(lightHex: 0x767680, lightAlpha: 0.12,
                                         darkHex: 0x767680, darkAlpha: 0.24)
    /// Selected-segment fill for the pill segmented selectors: an elevated chip that
    /// reads *above* the `fillTertiary` track in both modes (white in light; a raised
    /// gray in dark, where `card` would sink below the track).
    static let segmentedSelected = Color(light: 0xFFFFFF, dark: 0x545458)

    // Thermostat surfaces (intentionally dark surfaces in both modes)
    static let thermostatCard    = Color(hex: 0x485057)
    static let thermostatScreen  = Color(hex: 0x3B4148)
    static let controlFill       = Color(hex: 0x2C3238)

    // System-mode colors used by the Usage runtime breakdown.
    static let coolingBlue       = Color(hex: 0x0093C8)
    static let heatingOrange     = Color(hex: 0xF76707)
    static let auxRed            = Color(hex: 0xE61234)
    static let fanPurple         = Color(hex: 0xC5B1C2)

    // Brand — lightened in dark mode for contrast on dark surfaces.
    static let brandNavy         = Color(light: 0x14435F, dark: 0x8FB8CE)
    /// Filled brand surface used by the onboarding "Welcome" spotlight card.
    static let brandTeal         = Color(hex: 0x006998)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8)  & 0xff) / 255,
                  blue:  Double(hex & 0xff)         / 255,
                  opacity: alpha)
    }

    /// An adaptive color that resolves to `light` in light mode, `dark` in dark mode.
    init(light: UInt, dark: UInt) {
        self.init(lightHex: light, darkHex: dark)
    }

    /// Adaptive color with independent per-appearance opacity (for system-style fills).
    init(lightHex: UInt, lightAlpha: Double = 1, darkHex: UInt, darkAlpha: Double = 1) {
        #if canImport(UIKit)
        self = Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let hex = isDark ? darkHex : lightHex
            return UIColor(
                red:   CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 8)  & 0xff) / 255,
                blue:  CGFloat(hex & 0xff)         / 255,
                alpha: CGFloat(isDark ? darkAlpha : lightAlpha)
            )
        })
        #else
        self.init(hex: lightHex, alpha: lightAlpha)
        #endif
    }
}

/// The lowercase "sensi" wordmark, approximated with a rounded system face.
struct SensiWordmark: View {
    var color: Color = .black
    var size: CGFloat = 34
    var body: some View {
        Image("sensi.logo")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(height: size)
            .foregroundStyle(color)
            .accessibilityLabel("sensi")
    }
}

/// A colored strength/level bar: green while healthy, yellow as it wanes, red when low.
/// Shared by reminder life and the thermostat's Wi-Fi/battery strength readouts.
struct MetricBar: View {
    let progress: Double
    /// When nil the bar is decorative (hidden from assistive tech).
    var accessibilityLabel: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SMA.fillTertiary)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 12)
        .padding(.vertical, 6)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityHidden(accessibilityLabel == nil)
    }

    private var color: Color {
        switch progress {
        case 0.5...:  return Color(hex: 0x34C759)
        case 0.25...: return Color(hex: 0xFFCC00)
        default:      return SMA.destructive
        }
    }
}

/// Rounded white "card" container used throughout the grouped screens.
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .containerShape(shape)
            .background(SMA.card, in: shape)
            .clipShape(shape)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }

    /// Hides the navigation bar in a cross-platform way (no-op on macOS).
    @ViewBuilder
    func hideNavBar() -> some View {
        #if os(iOS)
        self.toolbarVisibility(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Applies the inline navigation title style on iOS (no-op on macOS).
    @ViewBuilder
    func inlineNavTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// The shared inset-grouped list chrome used across the grouped screens:
    /// hidden system background, brand card row backgrounds, and the grouped
    /// backdrop extended under the safe area.
    func groupedListChrome() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
    }

    /// Constrains free-flowing content (VStack/ScrollView) to a centered readable
    /// column on regular width (iPad); leaves compact (iPhone) untouched.
    func readableWidth(_ maxWidth: CGFloat = 560) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }

    /// Constrains a greedy `Form`/`List` to a centered readable column on regular
    /// width. A list always fills its frame, so it must be centered with flanking
    /// spacers rather than a plain `.frame(maxWidth:)`.
    func readableFormWidth(_ maxWidth: CGFloat = 560) -> some View {
        modifier(ReadableFormWidth(maxWidth: maxWidth))
    }

    /// Wraps fixed (Spacer-distributed) content in a ScrollView that only scrolls
    /// when the content is taller than the available space. The content still fills
    /// the screen via `minHeight`, so Spacer-based layouts look identical when they
    /// fit and become scrollable (e.g. under large Dynamic Type) when they don't.
    func scrollableWhenNeeded() -> some View {
        GeometryReader { geo in
            ScrollView {
                self.frame(minWidth: geo.size.width, minHeight: geo.size.height)
            }
        }
    }
}

/// Centers VStack/ScrollView content at a max width on regular size class.
struct ReadableWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize
    var maxWidth: CGFloat = 560

    func body(content: Content) -> some View {
        if hSize == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

/// Centers a greedy `Form`/`List` at a max width on regular size class using
/// flanking spacers, since a list ignores a plain max-width frame.
struct ReadableFormWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize
    var maxWidth: CGFloat = 560

    func body(content: Content) -> some View {
        if hSize == .regular {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                content.frame(maxWidth: maxWidth)
                Spacer(minLength: 0)
            }
        } else {
            content
        }
    }
}
