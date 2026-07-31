import SwiftUI
import WidgetKit
import AppIntents
import UIKit

// MARK: - Colors (mirrors Theme.swift tokens, redeclared for the widget target)

private enum WC {
    static let heating      = Color(red: 0.969, green: 0.404, blue: 0.027) // #F76707
    static let cooling      = Color(red: 0.0,   green: 0.576, blue: 0.784) // #0093C8
    // Neutral card background used by the "I feel better now" button in every
    // activity state, so the button reads consistently regardless of heating /
    // cooling / fan. Uses `.secondary` so it adapts to light and dark mode.
    static let cardBackground = Color.secondary.opacity(0.10)
}

/// Builds a `Color` that resolves to a different value per color scheme,
/// so the widget's tinted tiles stay legible in both light and dark mode.
private func adaptive(light: Color, dark: Color) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(traits.userInterfaceStyle == .dark ? dark : light)
    })
}

private extension ComfortLevel {
    var tileColor: Color {
        switch self {
        case .cold:   adaptive(light: Color(red: 0.82, green: 0.91, blue: 0.98),
                               dark:  Color(red: 0.13, green: 0.22, blue: 0.33))
        case .chilly: adaptive(light: Color(red: 0.85, green: 0.93, blue: 0.97),
                               dark:  Color(red: 0.14, green: 0.24, blue: 0.30))
        case .stuffy: adaptive(light: Color(red: 0.89, green: 0.87, blue: 0.97),
                               dark:  Color(red: 0.20, green: 0.17, blue: 0.31))
        case .warm:   adaptive(light: Color(red: 0.98, green: 0.92, blue: 0.84),
                               dark:  Color(red: 0.30, green: 0.24, blue: 0.13))
        case .hot:    adaptive(light: Color(red: 0.99, green: 0.87, blue: 0.82),
                               dark:  Color(red: 0.33, green: 0.17, blue: 0.14))
        }
    }
}

private extension WidgetActivity {
    var tagline: String {
        switch self {
        case .idle:    ""
        case .heating: "Currently heating your home"
        case .cooling: "Currently cooling your home"
        case .fan:     "Currently running the fan"
        }
    }
    var labelColor: Color {
        switch self {
        case .heating: WC.heating
        case .cooling: WC.cooling
        case .fan, .idle: .secondary
        }
    }
}

// MARK: - Widget view

struct PetticoatWidgetView: View {
    let entry: PetticoatWidgetEntry
    private var snap: WidgetSnapshot { entry.snapshot }

    /// The optimistic guess (set on a comfort tap) takes precedence until the
    /// app writes the real activity and clears it.
    private var activity: WidgetActivity { snap.optimisticActivity ?? snap.activity }
    private var systemMode: WidgetSystemMode { snap.systemMode ?? .auto }
    private var showPicker: Bool { activity == .idle || snap.feedbackGiven }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(snap: snap, showThermostatName: entry.showThermostatName)
            Divider()
            if snap.isOffline == true {
                OfflineContent()
            } else if showPicker {
                ComfortPickerContent(deviceID: snap.deviceID, systemMode: systemMode)
            } else {
                ActivityContent(activity: activity, deviceID: snap.deviceID)
            }
        }
    }
}

// MARK: Header

private struct WidgetHeader: View {
    let snap: WidgetSnapshot
    let showThermostatName: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showThermostatName {
                Text(snap.deviceName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Image("sensi.logo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(height: 11)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(snap.currentTemp)°")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(snap.humidity)%")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: Offline state

private struct OfflineContent: View {
    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Thermostat Offline")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "petticoat://offline")!) {
                Text("Learn More")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(WC.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Comfort picker (idle state)

private struct ComfortPickerContent: View {
    let deviceID: String
    let systemMode: WidgetSystemMode

    private var availableLevels: [ComfortLevel] {
        ComfortLevel.allCases.filter { $0.isAvailable(for: systemMode) }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("How are you feeling?")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            HStack(spacing: 6) {
                ForEach(availableLevels) { level in
                    Button(intent: ComfortFeedbackIntent(level, deviceID: deviceID)) {
                        VStack(spacing: 4) {
                            Text(level.emoji)
                                .font(.title2)
                            Text(level.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(level.tileColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: Activity state (heating / cooling / fan)

private struct ActivityContent: View {
    let activity: WidgetActivity
    let deviceID: String

    var body: some View {
        VStack(spacing: 8) {
            Text(activity.tagline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activity.labelColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button(intent: FeelBetterIntent(deviceID: deviceID)) {
                VStack(spacing: 5) {
                    Text("😊")
                        .font(.title)
                    Text("I feel better now")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WC.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Widget definition

struct PetticoatWidget: Widget {
    let kind = WidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PetticoatWidgetIntent.self,
                               provider: PetticoatWidgetProvider()) { entry in
            PetticoatWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sensi")
        .description("See your home's comfort and thermostat status.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    PetticoatWidget()
} timeline: {
    PetticoatWidgetEntry(date: .now, snapshot: .sample, showThermostatName: false)
    PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        deviceID: "default", deviceName: "Home", currentTemp: 72, humidity: 40,
        activity: .heating, feedbackGiven: false), showThermostatName: true)
    PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        deviceID: "default", deviceName: "Home", currentTemp: 72, humidity: 40,
        activity: .cooling, feedbackGiven: false), showThermostatName: false)
    PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        deviceID: "default", deviceName: "Upstairs", currentTemp: 74, humidity: 44,
        activity: .idle, feedbackGiven: false, isOffline: true), showThermostatName: false)
}
