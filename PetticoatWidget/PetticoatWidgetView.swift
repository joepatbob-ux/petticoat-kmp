import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Colors (mirrors Theme.swift tokens, redeclared for the widget target)

private enum WC {
    static let heating      = Color(red: 0.969, green: 0.404, blue: 0.027) // #F76707
    static let heatingTint  = Color(red: 0.969, green: 0.404, blue: 0.027).opacity(0.12)
    static let cooling      = Color(red: 0.0,   green: 0.576, blue: 0.784) // #0093C8
    static let coolingTint  = Color.secondary.opacity(0.10)
    static let fanTint      = Color.secondary.opacity(0.08)
}

private extension ComfortLevel {
    var tileColor: Color {
        switch self {
        case .cold:   Color(red: 0.82, green: 0.91, blue: 0.98)
        case .chilly: Color(red: 0.85, green: 0.93, blue: 0.97)
        case .stuffy: Color(red: 0.89, green: 0.87, blue: 0.97)
        case .warm:   Color(red: 0.98, green: 0.92, blue: 0.84)
        case .hot:    Color(red: 0.99, green: 0.87, blue: 0.82)
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
    var cardTint: Color {
        switch self {
        case .heating: WC.heatingTint
        case .cooling: WC.coolingTint
        case .fan:     WC.fanTint
        case .idle:    .clear
        }
    }
}

// MARK: - Widget view

struct PetticoatWidgetView: View {
    let entry: PetticoatWidgetEntry
    private var snap: WidgetSnapshot { entry.snapshot }

    private var showPicker: Bool {
        snap.activity == .idle || snap.feedbackGiven
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(snap: snap)
            if showPicker {
                ComfortPickerContent(deviceID: snap.deviceID)
            } else {
                ActivityContent(activity: snap.activity, deviceID: snap.deviceID)
            }
        }
    }
}

// MARK: Header

private struct WidgetHeader: View {
    let snap: WidgetSnapshot

    var body: some View {
        HStack(spacing: 0) {
            Text(snap.deviceName)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "thermometer.medium")
                        .font(.caption2)
                        .foregroundStyle(WC.heating)
                    Text("\(snap.currentTemp)°")
                        .font(.footnote.weight(.semibold))
                }
                HStack(spacing: 3) {
                    Image(systemName: "humidity.fill")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    Text("\(snap.humidity)%")
                        .font(.footnote)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}

// MARK: Comfort picker (idle state)

private struct ComfortPickerContent: View {
    let deviceID: String

    var body: some View {
        VStack(spacing: 8) {
            Text("How are you feeling?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                ForEach(ComfortLevel.allCases) { level in
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
                .background(activity.cardTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    PetticoatWidgetEntry(date: .now, snapshot: .sample)
    PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        deviceID: "default", deviceName: "Home", currentTemp: 72, humidity: 40,
        activity: .heating, feedbackGiven: false))
    PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot(
        deviceID: "default", deviceName: "Home", currentTemp: 72, humidity: 40,
        activity: .cooling, feedbackGiven: false))
}
