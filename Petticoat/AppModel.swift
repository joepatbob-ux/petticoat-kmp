import SwiftUI
import Observation

// MARK: - Mock models

struct Device: Identifiable {
    let id = UUID()
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

    static let sampleUpstairs = Device(
        name: "Upstairs",
        location: "St. Louis, MO",
        currentTemp: 74,
        setpoint: 72,
        heatTo: 70,
        keepMin: 66,
        keepMax: 76,
        holdUntil: "6:00AM or Away",
        humidity: 44,
        outdoorTemp: 89,
        outdoorHigh: 89,
        outdoorLow: 81,
        scheduleName: "Comfort",
        sensorSummary: "1 of 2 Sensors",
        sensors: [
            RoomSensor(name: "Thermostat", temp: 74, humidity: 44, participating: true),
            RoomSensor(name: "Nursery",    temp: 72, humidity: 46, participating: false, battery: 63),
        ]
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
    /// The three card treatments from the design system. Promotional is the filled
    /// brand card; Generic is a first-party white card; Partner is a co-branded
    /// white card.
    enum Kind { case promotional, generic, partner }

    let id = UUID()
    var kind: Kind = .generic
    let provider: String
    let title: String
    let body: String
    var validUntil: String = ""
    /// CTA label; falls back to the kind's default when nil.
    var actionLabel: String? = nil
    /// Hero asset name; falls back to the kind's default when nil.
    var heroImage: String? = nil
    /// Onboarding cards launch the install flow from their CTA (and can't be
    /// dismissed); other cards open their detail.
    var startsInstall: Bool = false

    /// The "Expires: …" line under the body (empty when there's no expiry).
    var subline: String { validUntil.isEmpty ? "" : "Expires: \(validUntil)" }

    /// The filled onboarding card shown when no thermostat has been added yet.
    static let welcome = SpotlightItem(
        kind: .promotional,
        provider: "",
        title: "Welcome to the Sensi!",
        body: "Let’s get started by installing your Sensi Thermostat.",
        startsInstall: true
    )

    static let samples = [
        SpotlightItem(
            kind: .promotional,
            provider: "",
            title: "Get more from your Sensi",
            body: "Explore Smart Alerts, energy insights, and remote room sensors.",
            validUntil: "June 27, 2024"
        ),
        SpotlightItem(
            kind: .partner,
            provider: "ACME POWER",
            title: "Save with the EcoSmart program!",
            body: "Optimize your energy usage by registering to the EcoSmart program today!",
            validUntil: "July 15, 2025"
        ),
        SpotlightItem(
            kind: .generic,
            provider: "SENSI",
            title: "Your July usage report is ready",
            body: "See how your energy use compared to last month and get personalized tips to save.",
            validUntil: "August 1, 2025"
        ),
    ]
}

extension SpotlightItem.Kind {
    /// Filled cards use the brand surface with white text; others are white cards.
    var isFilled: Bool { self == .promotional }

    var defaultActionLabel: String { self == .promotional ? "Get Started" : "Learn More" }

    var defaultHero: String {
        switch self {
        case .promotional: "spotlight.hero.sensor"
        case .generic:     "spotlight.hero.energy"
        case .partner:     "spotlight.hero.partner"
        }
    }

    /// Capsule fill behind the action button.
    var buttonTint: Color {
        switch self {
        case .promotional: .white
        case .generic:     Color(hex: 0x15CB70)   // System Mode / Energy Green
        case .partner:     SMA.orange
        }
    }

    var buttonLabelColor: Color { self == .promotional ? SMA.brandTeal : .white }

    /// Ellipsis and other accents — white on the filled card, brand blue otherwise.
    var accent: Color { self == .promotional ? .white : SMA.accent }
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

    /// All paired thermostats, shown as resortable cards on the dashboard. Empty
    /// means no thermostat has been added yet (the dashboard shows the onboarding
    /// welcome card instead).
    var devices: [Device] = [.sample, .sampleUpstairs]
    /// The device the single-device screens (Control, Mode, Schedule) act on.
    var selectedDeviceID: Device.ID? = nil
    var spotlights: [SpotlightItem] = SpotlightItem.samples

    /// The currently selected device — a read/write proxy into `devices` so the
    /// existing single-device screens keep working unchanged.
    var device: Device {
        get { devices.first { $0.id == selectedDeviceID } ?? devices.first ?? .sample }
        set {
            let i = devices.firstIndex { $0.id == selectedDeviceID } ?? devices.startIndex
            guard devices.indices.contains(i) else { return }
            devices[i] = newValue
        }
    }

    /// Make a device the target of the single-device screens.
    func selectDevice(_ id: Device.ID) { selectedDeviceID = id }

    /// Reorder the dashboard thermostat cards (from the Manage Devices screen).
    func moveDevices(from source: IndexSet, to destination: Int) {
        devices.move(fromOffsets: source, toOffset: destination)
    }

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
    func adjustKeep(_ bound: SetpointBound, by delta: Int, in id: Device.ID) {
        guard let i = devices.firstIndex(where: { $0.id == id }) else { return }
        let lo = SetpointConfig.minTemp
        let hi = SetpointConfig.maxTemp
        let gap = SetpointConfig.deadband

        var d = devices[i]
        if d.systemMode.isRangeSetpoint {
            switch bound {
            case .low:
                let v = min(max(d.keepMin + delta, lo), hi - gap)
                d.keepMin = v
                if d.keepMax < v + gap { d.keepMax = v + gap }
            case .high:
                let v = min(max(d.keepMax + delta, lo + gap), hi)
                d.keepMax = v
                if d.keepMin > v - gap { d.keepMin = v - gap }
            }
        } else if d.systemMode == .cool {
            d.keepMax = min(max(d.keepMax + delta, lo + gap), hi)
            d.keepMin = min(d.keepMin, d.keepMax - gap)
        } else {   // heat / auxHeat
            d.keepMin = min(max(d.keepMin + delta, lo), hi - gap)
            d.keepMax = max(d.keepMax, d.keepMin + gap)
        }
        devices[i] = d

        if controlMode == .schedule || controlMode == .activity {
            withAnimation(.snappy) { controlMode = .hold }
        }
    }

    /// Convenience for the single-device screens: adjusts the selected device.
    func adjustKeep(_ bound: SetpointBound, by delta: Int) {
        adjustKeep(bound, by: delta, in: device.id)
    }

    /// Toggle whether a paired sensor feeds the averaged temperature on a device.
    func toggleSensor(_ sensor: RoomSensor, in id: Device.ID) {
        guard let di = devices.firstIndex(where: { $0.id == id }),
              let si = devices[di].sensors.firstIndex(where: { $0.id == sensor.id }) else { return }
        withAnimation(.snappy) { devices[di].sensors[si].participating.toggle() }
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
