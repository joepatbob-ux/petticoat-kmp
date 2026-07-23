import SwiftUI
import Observation

// MARK: - Mock models

struct Device {
    let name: String
    let location: String
    var currentTemp: Int
    var setpoint: Int
    var heatTo: Int
    var keepMin: Int
    var keepMax: Int
    let holdUntil: String
    let humidity: Int
    let outdoorTemp: Int
    let outdoorHigh: Int
    let outdoorLow: Int
    let scheduleName: String
    let sensorSummary: String
    /// Room sensors paired with this thermostat, shown in the dashboard card's
    /// expandable list. `participating` sensors feed the averaged temperature.
    var sensors: [RoomSensor] = RoomSensor.samples
    var systemMode: SystemMode = .auto
    var fanMode: FanMode = .auto
    var circulateFan: Bool = true
    var circulateAmount: String = "33% (15min)"
    /// Location-based auto home/away. When on, the current schedule period can end
    /// early if the geofence is crossed — surfaced by the location pin in the footer.
    var geofenceEnabled: Bool = true
    /// Whether the preset switcher is offered on the control screen when not
    /// running a schedule.
    var usePresets: Bool = true
    /// Pre-heat/cool ahead of a scheduled period so the setpoint is reached on time.
    var earlyStart: Bool = true

    /// Whether the HVAC is actively calling, derived from mode + temp vs. range.
    var activity: HVACActivity {
        switch systemMode {
        case .off:            return .idle
        case .cool:           return currentTemp > keepMax ? .cooling : .idle
        case .heat, .auxHeat: return currentTemp < keepMin ? .heating : .idle
        case .auto:
            if currentTemp < keepMin { return .heating }
            if currentTemp > keepMax { return .cooling }
            return .idle
        }
    }

    /// How many paired sensors currently feed the averaged temperature.
    var participatingCount: Int { sensors.filter(\.participating).count }

    static let sample = Device(
        name: "Home",
        location: "St. Louis, MO",
        currentTemp: 72,
        setpoint: 72,
        heatTo: 75,
        keepMin: 62,
        keepMax: 73,
        holdUntil: "6:00AM or Away",
        humidity: 40,
        outdoorTemp: 89,
        outdoorHigh: 89,
        outdoorLow: 81,
        scheduleName: "Comfort",
        sensorSummary: "2 of 3 Sensors"
    )
}

/// A paired room sensor. `participating` means it contributes to the averaged
/// temperature the thermostat controls to. `battery` is the remaining charge
/// (0–100), or nil for hard-wired models that have no battery.
struct RoomSensor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let temp: Int
    let humidity: Int
    var participating: Bool
    var battery: Int? = nil

    /// Battery icon that steps down with the remaining charge.
    static func batterySymbol(_ level: Int) -> String {
        switch level {
        case 67...:   "battery.100"
        case 34...66: "battery.50"
        case 1...33:  "battery.25"
        default:      "battery.0"
        }
    }

    /// Green while healthy, orange as it wanes, red when nearly dead.
    static func batteryColor(_ level: Int) -> Color {
        switch level {
        case 50...:    Color(hex: 0x34C759)
        case 20..<50:  SMA.orange
        default:       SMA.destructive
        }
    }

    static let samples = [
        RoomSensor(name: "Thermostat", temp: 72, humidity: 40, participating: true),                // wired
        RoomSensor(name: "Bedroom",    temp: 70, humidity: 42, participating: true,  battery: 41),
        RoomSensor(name: "Office",     temp: 75, humidity: 38, participating: false, battery: 12),
    ]
}

struct SpotlightItem: Identifiable {
    let id = UUID()
    let provider: String
    let title: String
    let body: String
    var validUntil: String = ""
    /// Call-to-action label for filled onboarding cards (e.g. "Get Started").
    var actionLabel: String? = nil

    /// The filled onboarding card shown when no thermostat has been added yet.
    static let welcome = SpotlightItem(
        provider: "",
        title: "Welcome to the Sensi!",
        body: "Let’s get started by installing your Sensi Thermostat.",
        actionLabel: "Get Started"
    )

    static let samples = [
        SpotlightItem(
            provider: "ACME POWER",
            title: "Save with the EcoSmart program!",
            body: "Optimize your energy usage by registering to the EcoSmart program today!",
            validUntil: "July 15, 2025"
        ),
        SpotlightItem(
            provider: "SENSI",
            title: "Your July usage report is ready",
            body: "See how your energy use compared to last month and get personalized tips to save.",
            validUntil: "August 1, 2025"
        ),
    ]
}

// MARK: - App state

/// Which end of the comfort range is being adjusted.
enum SetpointBound { case low, high }

/// Shared limits for setpoint adjustment. Heat and cool setpoints must stay at
/// least `deadband` degrees apart; pushing one into the other drags it along.
enum SetpointConfig {
    static let minTemp = 45
    static let maxTemp = 95
    static let deadband = 2
}

/// Current HVAC call state, derived from temperature vs. the comfort range.
enum HVACActivity { case idle, heating, cooling }

/// How the controller is currently deciding setpoints, which drives the controller UI.
enum ControlMode: Equatable {
    case standard    // manual, no schedule
    case schedule    // following the schedule (shows the timeline)
    case hold        // temporary manual override of the schedule
    case activity    // running an activity profile
    case vacation    // vacation hold
}

enum SystemMode: String, CaseIterable, Identifiable {
    case cool, heat, auxHeat, auto, off
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cool:    "Cool"
        case .heat:    "Heat"
        case .auxHeat: "AUX"
        case .auto:    "Auto"
        case .off:     "Off"
        }
    }
    /// Custom multicolor icon asset in the catalog.
    var iconName: String {
        switch self {
        case .cool:    "mode.cool"
        case .heat:    "mode.heat"
        case .auxHeat: "mode.auxHeat"
        case .auto:    "mode.auto"
        case .off:     "mode.off"
        }
    }
    /// The label shown above the setpoint at rest: a range in Auto, a single
    /// target when heating or cooling.
    var setpointLabel: String {
        switch self {
        case .heat, .auxHeat: "Heat To"
        case .cool:           "Cool To"
        default:              "Keep Between"
        }
    }
    /// Auto controls to a low·high range; heat/cool control to a single target.
    var isRangeSetpoint: Bool { self == .auto || self == .off }
}

enum FanMode: String, CaseIterable, Identifiable {
    case auto, on
    var id: String { rawValue }
    var label: String { self == .auto ? "Auto" : "On" }
    /// Custom fan icon asset in the catalog.
    var iconName: String { self == .auto ? "fan.auto" : "fan.on" }
}

/// One period in the day's schedule timeline, shown as a swipeable controller page.
struct TimelinePeriod: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var symbol: String
    var colorHex: UInt
    var heatTo: Int
    var coolTo: Int
    var startText: String
}

@Observable
final class AppModel {
    enum Route { case splash, login, main }

    var route: Route = .splash
    var showAccount = false
    var showAddDevice = false
    var showHelp = false

    var device = Device.sample
    var spotlights: [SpotlightItem] = SpotlightItem.samples
    /// Whether any thermostat has been added. When false, the dashboard shows the
    /// filled welcome/onboarding spotlight in place of a device card.
    var hasThermostat = true

    /// Drives the controller UI. Defaults to following the schedule (timeline).
    var controlMode: ControlMode = .schedule
    /// The activity profile shown when `controlMode == .activity` (and as the
    /// current-period label while on a schedule).
    var activeProfile = ActivityProfile.samples[1]   // Home
    /// All activity profiles (the Presets list). Single source of truth.
    var activityProfiles: [ActivityProfile] = ActivityProfile.samples
    /// Upcoming schedule periods (after the current one) shown in the controller pager.
    var upcomingPeriods: [TimelinePeriod] = [
        .init(name: "Away",  symbol: "figure.walk",     colorHex: 0x30B0C7, heatTo: 62, coolTo: 80, startText: "8:00 AM"),
        .init(name: "Home",  symbol: "house.fill",      colorHex: 0xFF9500, heatTo: 70, coolTo: 74, startText: "5:30 PM"),
        .init(name: "Sleep", symbol: "bed.double.fill", colorHex: 0xAF52DE, heatTo: 66, coolTo: 72, startText: "10:00 PM"),
    ]

    /// Adjusts the comfort setpoint. In Auto this moves one bound of the range and,
    /// honoring the two-degree deadband, pushes the opposite bound when they'd
    /// collide. In heat/cool it moves the single active target. Adjusting while
    /// following a schedule or profile creates a temporary hold.
    func adjustKeep(_ bound: SetpointBound, by delta: Int) {
        let lo = SetpointConfig.minTemp
        let hi = SetpointConfig.maxTemp
        let gap = SetpointConfig.deadband

        if device.systemMode.isRangeSetpoint {
            switch bound {
            case .low:
                let v = min(max(device.keepMin + delta, lo), hi - gap)
                device.keepMin = v
                if device.keepMax < v + gap { device.keepMax = v + gap }
            case .high:
                let v = min(max(device.keepMax + delta, lo + gap), hi)
                device.keepMax = v
                if device.keepMin > v - gap { device.keepMin = v - gap }
            }
        } else if device.systemMode == .cool {
            device.keepMax = min(max(device.keepMax + delta, lo + gap), hi)
            device.keepMin = min(device.keepMin, device.keepMax - gap)
        } else {   // heat / auxHeat
            device.keepMin = min(max(device.keepMin + delta, lo), hi - gap)
            device.keepMax = max(device.keepMax, device.keepMin + gap)
        }

        if controlMode == .schedule || controlMode == .activity {
            withAnimation(.snappy) { controlMode = .hold }
        }
    }

    /// Toggle whether a paired sensor feeds the averaged temperature.
    func toggleSensor(_ sensor: RoomSensor) {
        guard let i = device.sensors.firstIndex(where: { $0.id == sensor.id }) else { return }
        withAnimation(.snappy) { device.sensors[i].participating.toggle() }
    }

    /// Automation Schedule/Off toggle drives schedule vs. standard control.
    func setScheduleEnabled(_ enabled: Bool) {
        withAnimation(.snappy) { controlMode = enabled ? .schedule : .standard }
    }

    /// Activate an activity profile as the current controller mode.
    func activateProfile(_ profile: ActivityProfile) {
        activeProfile = profile
        withAnimation(.snappy) { controlMode = .activity }
    }

    /// Insert a new profile or update an existing one (matched by id).
    func saveProfile(_ updated: ActivityProfile) {
        if let i = activityProfiles.firstIndex(where: { $0.id == updated.id }) {
            activityProfiles[i] = updated
        } else {
            activityProfiles.append(updated)
        }
        if activeProfile.id == updated.id { activeProfile = updated }
    }

    func duplicateProfile(_ profile: ActivityProfile) {
        guard let i = activityProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let copy = ActivityProfile(name: profile.name + " Copy", symbol: profile.symbol, colorHex: profile.colorHex,
                                   heatTo: profile.heatTo, coolTo: profile.coolTo, subtitle: profile.subtitle)
        activityProfiles.insert(copy, at: i + 1)
    }

    func deleteProfile(_ profile: ActivityProfile) {
        activityProfiles.removeAll { $0.id == profile.id }
    }

    func setVacation(_ on: Bool) {
        withAnimation(.snappy) { controlMode = on ? .vacation : .schedule }
    }

    /// Resume the schedule, clearing any hold/vacation.
    func resumeSchedule() {
        withAnimation(.snappy) { controlMode = .schedule }
    }

    /// Dismisses a spotlight card. When the last card is dismissed the Spotlight area
    /// is hidden entirely.
    func dismissSpotlight(_ item: SpotlightItem) {
        withAnimation { spotlights.removeAll { $0.id == item.id } }
    }

    func signIn() {
        withAnimation(.easeInOut) { route = .main }
    }

    func signOut() {
        showAccount = false
        withAnimation(.easeInOut) { route = .login }
    }
}
