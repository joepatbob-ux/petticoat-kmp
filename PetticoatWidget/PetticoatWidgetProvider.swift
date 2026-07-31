import WidgetKit
import SwiftUI

struct PetticoatWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let showThermostatName: Bool
}

struct PetticoatWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PetticoatWidgetEntry {
        PetticoatWidgetEntry(date: .now, snapshot: .sample, showThermostatName: false)
    }

    func snapshot(for configuration: PetticoatWidgetIntent,
                  in context: Context) async -> PetticoatWidgetEntry {
        let deviceID = configuration.thermostat?.id ?? WidgetSnapshot.loadDeviceList().first?.id ?? ""
        return PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot.load(deviceID: deviceID),
                                    showThermostatName: configuration.showThermostatName)
    }

    func timeline(for configuration: PetticoatWidgetIntent,
                  in context: Context) async -> Timeline<PetticoatWidgetEntry> {
        let deviceID = configuration.thermostat?.id ?? WidgetSnapshot.loadDeviceList().first?.id ?? ""
        let entry = PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot.load(deviceID: deviceID),
                                         showThermostatName: configuration.showThermostatName)
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}
