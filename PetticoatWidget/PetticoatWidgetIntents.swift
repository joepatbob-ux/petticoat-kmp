import AppIntents
import WidgetKit

// MARK: - Thermostat entity (for the widget configuration picker)

struct ThermostatEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Thermostat"
    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
    static var defaultQuery = ThermostatEntityQuery()
}

struct ThermostatEntityQuery: EntityQuery {
    func entities(for identifiers: [ThermostatEntity.ID]) async throws -> [ThermostatEntity] {
        WidgetSnapshot.loadDeviceList()
            .filter { identifiers.contains($0.id) }
            .map { ThermostatEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ThermostatEntity] {
        WidgetSnapshot.loadDeviceList()
            .map { ThermostatEntity(id: $0.id, name: $0.name) }
    }
}

/// Widget configuration intent — lets the user pick which thermostat to show.
struct PetticoatWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Thermostat"
    static var description = IntentDescription("Choose which thermostat to display.")

    @Parameter(title: "Thermostat") var thermostat: ThermostatEntity?
}

// MARK: - ComfortLevel as AppEnum

private extension ComfortLevel {
    var setpointDelta: Int? {
        switch self {
        case .cold:   +5
        case .chilly: +2
        case .stuffy: nil
        case .warm:   -2
        case .hot:    -5
        }
    }
    var triggersFanRun: Bool { self == .stuffy }
}

extension ComfortLevel: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Comfort Level" }
    static var caseDisplayRepresentations: [ComfortLevel: DisplayRepresentation] {
        [
            .cold:   "Cold",
            .chilly: "Chilly",
            .stuffy: "Stuffy",
            .warm:   "Warm",
            .hot:    "Hot",
        ]
    }
}

// MARK: - Comfort feedback intents

/// Tapping a comfort emoji tile records the level, writes the thermostat
/// adjustment command, and returns the widget to the HVAC activity state.
struct ComfortFeedbackIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Comfort Level"

    @Parameter(title: "Level") var level: ComfortLevel
    @Parameter(title: "Device ID") var deviceID: String

    init() {}
    init(_ level: ComfortLevel, deviceID: String) {
        self.level = level
        self.deviceID = deviceID
    }

    func perform() async throws -> some IntentResult {
        var snap = WidgetSnapshot.load(deviceID: deviceID)
        snap.comfortFeedback = level
        snap.feedbackGiven = false
        snap.pendingSetpointDelta = level.setpointDelta
        snap.pendingFanRun = level.triggersFanRun ? true : nil
        snap.save()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        return .result()
    }
}

/// Tapping "I feel better now" signals satisfaction and shows the comfort picker.
struct FeelBetterIntent: AppIntent {
    static var title: LocalizedStringResource = "I Feel Better Now"

    @Parameter(title: "Device ID") var deviceID: String

    init() {}
    init(deviceID: String) { self.deviceID = deviceID }

    func perform() async throws -> some IntentResult {
        var snap = WidgetSnapshot.load(deviceID: deviceID)
        snap.feedbackGiven = true
        snap.comfortFeedback = nil
        snap.save()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        return .result()
    }
}
