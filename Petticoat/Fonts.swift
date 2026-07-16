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
