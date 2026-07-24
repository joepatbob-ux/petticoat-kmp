import SwiftUI
import CoreText

/// Registers any font files bundled with the app target at launch, so custom
/// fonts (e.g. Lato) work without editing Info.plist. Safe no-op if none exist.
enum FontRegistrar {
    static func registerBundledFonts() {
        for ext in ["ttf", "otf"] {
            let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            for url in urls {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

extension SMA {
    /// Font for the large temperature readouts (display temp): Lato-Light when
    /// the system is idle, Lato-Bold when it is actively heating/cooling.
    /// Falls back to the system font until the Lato files are added to the target.
    static func displayTemp(size: CGFloat, activity: HVACActivity) -> Font {
        Font.custom(activity == .idle ? "Lato-Light" : "Lato-Bold", size: size)
    }

    /// Display-temp color, paired to the HVAC call state.
    static func tempColor(_ activity: HVACActivity) -> Color {
        switch activity {
        case .heating: SMA.tempOrange
        case .cooling: SMA.accent
        case .idle:    SMA.tempIdle
        }
    }
}

/// The large temperature readout. When the system starts or stops heating/cooling
/// it animates between the two type styles. Two custom-font weights (Lato-Light for
/// idle, Lato-Bold for active) can't interpolate, so the idle and active renderings
/// are layered and cross-faded; heating↔cooling is a color tween on the active layer.
struct DisplayTemp: View {
    let value: Int
    var size: CGFloat
    let activity: HVACActivity

    private var activeColor: Color { activity == .cooling ? SMA.accent : SMA.tempOrange }

    var body: some View {
        ZStack {
            Text("\(value)")
                .font(SMA.displayTemp(size: size, activity: .idle))
                .foregroundStyle(SMA.tempColor(.idle))
                .opacity(activity == .idle ? 1 : 0)

            Text("\(value)")
                .font(SMA.displayTemp(size: size, activity: .heating))
                .foregroundStyle(activeColor)
                .opacity(activity == .idle ? 0 : 1)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.45), value: activity)
        .animation(.snappy, value: value)
        .accessibilityElement()
        .accessibilityLabel("\(value) degrees")
    }
}
