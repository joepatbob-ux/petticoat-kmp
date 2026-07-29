import Foundation

/// Lightweight device descriptor written by the app so the widget's EntityQuery
/// can populate the thermostat picker without importing any app types.
struct WidgetDeviceInfo: Codable, Equatable {
    var id: String
    var name: String
}

/// Shared model between the main app and the widget extension.
/// Both targets must include this file — set membership in Xcode's
/// File Inspector (⌘⌥1) for each of the two targets.
struct WidgetSnapshot: Codable {
    var deviceID: String
    var deviceName: String
    var currentTemp: Int
    var humidity: Int
    var activity: WidgetActivity
    /// Set to true when the user taps "I feel better now" — causes the widget
    /// to show the comfort emoji picker instead of the HVAC activity state.
    var feedbackGiven: Bool
    var comfortFeedback: ComfortLevel?
    /// Setpoint delta written by a widget comfort tap (+5, +2, -2, -5).
    /// AppModel reads and clears this when the app becomes active.
    var pendingSetpointDelta: Int?
    /// True when the widget requested the fan to run for 2 hours (stuffy tap).
    var pendingFanRun: Bool?
    /// Activity the widget shows immediately after a comfort tap, before the app
    /// recomputes the real HVAC state. Kept separate from `activity` so the app's
    /// real-transition detection isn't confused by the widget's optimistic guess.
    /// The app clears it on the next `writeWidgetSnapshot()`.
    var optimisticActivity: WidgetActivity?

    // MARK: - App Group — shared between the app and widget extension.
    static let appGroupID    = "group.com.joepatbob.Petticoat"
    static let snapshotKey   = "widgetSnapshot"
    static let deviceListKey = "widgetDeviceList"
    static let widgetKind    = "PetticoatWidget"

    static let sample = WidgetSnapshot(
        deviceID: "default",
        deviceName: "Home",
        currentTemp: 72,
        humidity: 40,
        activity: .idle,
        feedbackGiven: false
    )

    // MARK: - Persistence

    static func load(deviceID: String = "default") -> WidgetSnapshot {
        guard
            let suite = UserDefaults(suiteName: Self.appGroupID),
            let data  = suite.data(forKey: "\(Self.snapshotKey)_\(deviceID)"),
            let snap  = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return WidgetSnapshot(deviceID: deviceID, deviceName: "Home",
                                  currentTemp: 72, humidity: 40, activity: .idle, feedbackGiven: false)
        }
        return snap
    }

    func save() {
        guard
            let suite = UserDefaults(suiteName: Self.appGroupID),
            let data  = try? JSONEncoder().encode(self)
        else { return }
        suite.set(data, forKey: "\(Self.snapshotKey)_\(deviceID)")
    }

    // MARK: - Device list (for the widget's thermostat picker)

    static func loadDeviceList() -> [WidgetDeviceInfo] {
        guard
            let suite = UserDefaults(suiteName: Self.appGroupID),
            let data  = suite.data(forKey: Self.deviceListKey),
            let list  = try? JSONDecoder().decode([WidgetDeviceInfo].self, from: data)
        else { return [] }
        return list
    }

    static func saveDeviceList(_ list: [WidgetDeviceInfo]) {
        guard
            let suite = UserDefaults(suiteName: Self.appGroupID),
            let data  = try? JSONEncoder().encode(list)
        else { return }
        suite.set(data, forKey: Self.deviceListKey)
    }
}

enum WidgetActivity: String, Codable, Equatable, Sendable {
    case idle, heating, cooling, fan
}

// Declares Sendable in the same file as the enum so the widget's
// `AppEnum` conformance (which refines Sendable) isn't a retroactive
// conformance in another file.
enum ComfortLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case cold, chilly, stuffy, warm, hot
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:   "Cold"
        case .chilly: "Chilly"
        case .stuffy: "Stuffy"
        case .warm:   "Warm"
        case .hot:    "Hot"
        }
    }

    var emoji: String {
        switch self {
        case .cold:   "🥶"
        case .chilly: "😦"
        case .stuffy: "😐"
        case .warm:   "😢"
        case .hot:    "🥵"
        }
    }
}
