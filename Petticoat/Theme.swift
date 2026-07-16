import SwiftUI

/// Design tokens pulled from the "SMA - iOS26" Figma file.
enum SMA {
    // Core palette
    static let accent            = Color(hex: 0x0088FF)
    static let groupedBackground = Color(hex: 0xF2F2F7)
    static let card              = Color.white
    static let labelPrimary      = Color(hex: 0x000000)
    static let labelSecondary    = Color(hex: 0x3C3C43).opacity(0.6)
    static let separator         = Color(hex: 0xE6E6E6)
    static let orange            = Color(hex: 0xF5A623)
    static let tempOrange        = Color(hex: 0xF16A1B)
    static let tempIdle          = Color(hex: 0x8E8E93)
    static let destructive       = Color(hex: 0xFF3B30)
    static let fillTertiary      = Color(hex: 0x767680).opacity(0.12)

    // Thermostat surfaces
    static let thermostatCard    = Color(hex: 0x485057)
    static let thermostatScreen  = Color(hex: 0x3B4148)
    static let controlFill       = Color(hex: 0x2C3238)

    // Brand
    static let brandBlue         = Color(hex: 0x0E80B7)
    static let brandNavy         = Color(hex: 0x14435F)

    // Splash gradient
    static let splashTop         = Color(hex: 0x0E80B7)
    static let splashBottom      = Color(hex: 0x0A6C9B)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8)  & 0xff) / 255,
                  blue:  Double(hex & 0xff)         / 255,
                  opacity: alpha)
    }
}

/// The lowercase "sensi" wordmark, approximated with a rounded system face.
struct SensiWordmark: View {
    var color: Color = .black
    var size: CGFloat = 34
    var body: some View {
        Text("sensi")
            .font(.system(size: size, weight: .regular, design: .rounded))
            .foregroundStyle(color)
    }
}

/// "sensi / by COPELAND" lockup used on Splash and Login.
struct SensiLockup: View {
    var wordmarkColor: Color = .white
    var copelandColor: Color = .white
    var size: CGFloat = 64
    var body: some View {
        VStack(spacing: 2) {
            SensiWordmark(color: wordmarkColor, size: size)
            Text("by COPELAND")
                .font(.system(size: size * 0.28, weight: .heavy))
                .tracking(1)
                .foregroundStyle(copelandColor)
        }
    }
}

/// Rounded white "card" container used throughout the grouped screens.
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(SMA.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
}
