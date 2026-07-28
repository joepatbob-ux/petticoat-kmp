import WidgetKit
import SwiftUI

struct PetticoatWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct PetticoatWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PetticoatWidgetEntry {
        PetticoatWidgetEntry(date: .now, snapshot: .sample)
    }

    func snapshot(for configuration: PetticoatWidgetIntent,
                  in context: Context) async -> PetticoatWidgetEntry {
        let deviceID = configuration.thermostat?.id ?? ""
        return PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot.load(deviceID: deviceID))
    }

    func timeline(for configuration: PetticoatWidgetIntent,
                  in context: Context) async -> Timeline<PetticoatWidgetEntry> {
        let deviceID = configuration.thermostat?.id ?? ""
        let entry = PetticoatWidgetEntry(date: .now, snapshot: WidgetSnapshot.load(deviceID: deviceID))
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}
