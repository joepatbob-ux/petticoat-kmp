import SwiftUI
import Observation
import WidgetKit
import ActivityKit

// MARK: - Mock models

struct Device: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let location: String
    var currentTemp: Int
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
    /// How long the fan runs when Fan is set to On before returning to Auto.
    var fanHoldDuration: HoldDuration = .indefinite
    var circulateFan: Bool = true
    var circulateAmount: String = "33% (15min)"
    /// How long circulation stays active before returning to the schedule.
    var circulateHoldDuration: HoldDuration = .indefinite
    /// Location-based auto home/away. When on, the current schedule period can end
    /// early if the geofence is crossed — surfaced by the location pin in the footer.
    var geofenceEnabled: Bool = true
    /// Whether the preset switcher is offered on the control screen when not
    /// running a schedule.
    var usePresets: Bool = true
    /// Pre-heat/cool ahead of a scheduled period so the setpoint is reached on time.
    var earlyStart: Bool = true
    /// When true the thermostat has lost its Wi-Fi/cloud connection: the dashboard
    /// shows the Thermostat Offline card instead of the controls. `offlineSince` is
    /// a pre-formatted display string.
    var isOffline: Bool = false
    var offlineSince: String? = nil
    /// The home this thermostat belongs to. Nil means unassigned.
    var homeID: Home.ID? = nil

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
        ],
        isOffline: true,
        offlineSince: "4:00PM November 24, 2023"
    )
}

/// A paired room sensor. `participating` means it contributes to the averaged
/// temperature the thermostat controls to. `battery` is the remaining charge
/// (0–100), or nil for hard-wired models that have no battery.
struct RoomSensor: Identifiable, Hashable {
    let id = UUID()
    var name: String
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

/// A physical home that can contain one or more thermostats. Home-level settings
/// (size, HVAC type) affect time-to-temp estimates for all assigned thermostats.
struct Home: Identifiable, Equatable {
    var id: UUID
    var name: String
    var homeSize: HomeSize
    var hvacSystemType: HVACSystemType

    init(id: UUID = UUID(), name: String,
         homeSize: HomeSize = .medium,
         hvacSystemType: HVACSystemType = .gasFurnace) {
        self.id = id
        self.name = name
        self.homeSize = homeSize
        self.hvacSystemType = hvacSystemType
    }
}

struct SpotlightItem: Identifiable, Equatable {
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

/// Approximate home size used to scale the time-to-temp estimate.
/// Larger homes take longer even when HVAC capacity scales up, because
/// thermal mass, wall area, and duct runs all grow with square footage.
enum HomeSize: String, CaseIterable, Identifiable {
    case small, medium, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small:  "Small (< 1,000 sq ft)"
        case .medium: "Medium (1,000–2,500 sq ft)"
        case .large:  "Large (2,500–4,000 sq ft)"
        case .xlarge: "Very Large (4,000+ sq ft)"
        }
    }
    /// Multiplier applied to the baseline heating/cooling rate.
    /// Small homes reach temp faster; very large homes much slower.
    var rateMultiplier: Double {
        switch self {
        case .small:  1.35
        case .medium: 1.0
        case .large:  0.72
        case .xlarge: 0.50
        }
    }
}

/// The type of heating/cooling system installed in the home, used to scale the
/// time-to-temp estimate. Separate from `SystemMode` (which is the operating mode)
/// so this can be set once at the account level rather than derived from mode state.
enum HVACSystemType: String, CaseIterable, Identifiable {
    case gasFurnace, electricFurnace, heatPump, auxHeat
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gasFurnace:      "Gas Furnace"
        case .electricFurnace: "Electric Furnace / Heat Strip"
        case .heatPump:        "Heat Pump"
        case .auxHeat:         "Auxiliary / Emergency Heat"
        }
    }
    /// Multiplier on the heating rate — gas furnace outputs the highest peak heat.
    var heatingFactor: Double {
        switch self {
        case .gasFurnace:      1.25
        case .electricFurnace: 1.0
        case .heatPump:        0.90
        case .auxHeat:         0.80
        }
    }
}

/// How long a fan run, circulation, or temporary hold stays in effect before the
/// thermostat returns to its schedule. `.indefinite` runs until manually changed;
/// the rest expire after a fixed number of hours. Shared by the Mode sheet (Fan On
/// / Circulate) and the hold status sheet.
enum HoldDuration: String, CaseIterable, Identifiable {
    case indefinite, oneHour, twoHours, threeHours, sixHours, twelveHours
    var id: String { rawValue }
    var label: String {
        switch self {
        case .indefinite:  "Indefinite"
        case .oneHour:     "1 Hour"
        case .twoHours:    "2 Hours"
        case .threeHours:  "3 Hours"
        case .sixHours:    "6 Hours"
        case .twelveHours: "12 Hours"
        }
    }
    /// The number of hours this duration lasts, or nil when it runs indefinitely.
    var hours: Int? {
        switch self {
        case .indefinite:  nil
        case .oneHour:     1
        case .twoHours:    2
        case .threeHours:  3
        case .sixHours:    6
        case .twelveHours: 12
        }
    }

    /// The clock time this duration elapses, measured from `now` (nil = indefinite).
    func endDate(from now: Date = Date()) -> Date? {
        hours.flatMap { Calendar.current.date(byAdding: .hour, value: $0, to: now) }
    }

    /// A short "3:15 PM" end-time string, or nil when indefinite. Matches the
    /// time style used throughout the schedule screens.
    func endTimeText(from now: Date = Date()) -> String? {
        endDate(from: now).map { $0.formatted(date: .omitted, time: .shortened) }
    }
}

/// One period in the day's schedule timeline, shown as a swipeable controller page.
struct TimelinePeriod: Identifiable, Hashable {
    let id: UUID
    var name: String
    var symbol: String
    var colorHex: UInt
    var heatTo: Int
    var coolTo: Int
    var startText: String

    init(id: UUID = UUID(), name: String, symbol: String, colorHex: UInt,
         heatTo: Int, coolTo: Int, startText: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.heatTo = heatTo
        self.coolTo = coolTo
        self.startText = startText
    }

    /// Derived from a schedule event, preserving the event's identity so the pager's
    /// cards keep stable identity as the timeline recomputes.
    init(from e: ScheduleEvent) {
        self.init(id: e.id, name: e.name, symbol: e.symbol, colorHex: e.colorHex,
                  heatTo: e.heatTo, coolTo: e.coolTo, startText: e.timeText)
    }
}

/// The orderable sections of the dashboard.
enum DashboardSection: String, CaseIterable, Identifiable {
    case thermostats, spotlight
    var id: String { rawValue }
    var title: String { self == .thermostats ? "Thermostats" : "Spotlight" }
}

/// Controls whether the setpoint stepper shows +/− buttons or ↑↓ chevrons.
enum StepperStyle: String, CaseIterable, Identifiable {
    case plusMinus, chevron
    var id: String { rawValue }
    var label: String {
        switch self {
        case .plusMinus: "Plus / Minus"
        case .chevron:   "Chevrons"
        }
    }
    func upSymbol() -> String   { self == .chevron ? "chevron.up"   : "plus"  }
    func downSymbol() -> String { self == .chevron ? "chevron.down" : "minus" }
}

/// App appearance preference, shown as a swatch picker in Application Settings.
enum AppAppearance: String, CaseIterable, Identifiable {
    case light, system, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light:  "Light"
        case .system: "System"
        case .dark:   "Dark"
        }
    }
    /// The scheme to force, or nil to follow the device (System).
    var colorScheme: ColorScheme? {
        switch self {
        case .light:  .light
        case .dark:   .dark
        case .system: nil
        }
    }
}

@Observable
final class AppModel {
    enum Route { case splash, login, main }

    var route: Route = .splash
    var showAccount = false
    var showAddDevice = false
    var showHelp = false

    // Shared iPad detail state — lifted here so the hardware-keyboard menu bar
    // (`PetticoatCommands`) and `MainSplitView` drive the same selection.
    /// The device tab shown in the iPad detail pane.
    var selectedTab: DeviceTab = .control
    /// Whether the iPad sidebar (dashboard) column is visible.
    var sidebarVisible = true
    /// Presents the New Reminder editor in the iPad detail.
    var addingReminder = false

    /// Running Live Activity for the "time to temp" heating/cooling banner.
    private var liveActivity: Activity<PetticoatActivityAttributes>?

    /// All paired thermostats, shown as resortable cards on the dashboard. Empty
    /// means no thermostat has been added yet (the dashboard shows the onboarding
    /// welcome card instead).
    var devices: [Device] = [.sample, .sampleUpstairs] {
        didSet { recomputeDevice() }
    }
    /// The device the single-device screens (Control, Mode, Schedule) act on.
    var selectedDeviceID: Device.ID? = nil {
        didSet { recomputeDevice() }
    }
    var spotlights: [SpotlightItem] = SpotlightItem.samples
    /// Spotlight cards hidden from the dashboard (reversible, unlike dismiss).
    var hiddenSpotlights: Set<UUID> = []
    /// The order the dashboard sections appear in.
    var dashboardSectionOrder: [DashboardSection] = [.thermostats, .spotlight]
    /// Whether thermostat cards offer the participating-sensor disclosure.
    var showSensorsOnDashboard = true
    /// App appearance preference (Light / System / Dark).
    var appearance: AppAppearance = .system
    /// Whether the outdoor-weather location is shown on the control screen.
    var showWeatherLocation = true
    /// Whether the setpoint stepper uses +/− or ↑↓ chevrons.
    var stepperStyle: StepperStyle = .plusMinus
    /// All homes on the account. Each thermostat can be assigned to one home.
    var homes: [Home] = [Home(name: "Home")]

    /// Spotlight cards currently shown on the dashboard (respecting hidden state).
    var visibleSpotlights: [SpotlightItem] {
        spotlights.filter { !hiddenSpotlights.contains($0.id) }
    }

    /// The currently selected device, cached so views that read `model.device.x`
    /// depend only on this property — not the whole `devices` array. Kept in sync by
    /// `recomputeDevice()` whenever `devices` or `selectedDeviceID` changes.
    private(set) var device: Device = .sample

    private func recomputeDevice() {
        let resolved = devices.first { $0.id == selectedDeviceID } ?? devices.first ?? .sample
        if resolved != device { device = resolved }
        // The timeline depends on the device (usePresets / systemMode), so keep the
        // cache in step whenever the selected device changes.
        recomputeTimeline()
        writeWidgetSnapshot()
    }

    init() {
        // Assign sample devices to the default home so they show up pre-assigned.
        let defaultID = homes.first?.id
        for i in devices.indices { devices[i].homeID = defaultID }
        // Seed the cached device + timeline (property `didSet`s don't fire for
        // initial values).
        recomputeDevice()
    }

    /// Write-through projection into the selected device for two-way bindings
    /// (`$model[device: \.systemMode]`), keeping `devices` the source of truth. Reads
    /// hit the cached `device`; writes route into `devices`, which refreshes the cache.
    subscript<Value>(device keyPath: WritableKeyPath<Device, Value>) -> Value {
        get { device[keyPath: keyPath] }
        set {
            guard let i = devices.firstIndex(where: { $0.id == device.id }) else { return }
            devices[i][keyPath: keyPath] = newValue
        }
    }

    /// Make a device the target of the single-device screens.
    func selectDevice(_ id: Device.ID) { selectedDeviceID = id }

    /// Bring the selected thermostat back online after a successful Wi-Fi reconnect,
    /// clearing the offline card and its "offline since" timestamp.
    func markSelectedDeviceOnline() {
        guard let i = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[i].isOffline = false
        devices[i].offlineSince = nil
    }

    /// Reorder the dashboard thermostat cards (from the Organize Dashboard screen).
    func moveDevices(from source: IndexSet, to destination: Int) {
        devices.move(fromOffsets: source, toOffset: destination)
    }

    /// Reorder the spotlight cards.
    func moveSpotlights(from source: IndexSet, to destination: Int) {
        spotlights.move(fromOffsets: source, toOffset: destination)
    }

    /// Reorder the dashboard sections themselves.
    func moveDashboardSections(from source: IndexSet, to destination: Int) {
        dashboardSectionOrder.move(fromOffsets: source, toOffset: destination)
    }

    /// Show or hide a spotlight card on the dashboard (reversible).
    func setSpotlight(_ item: SpotlightItem, hidden: Bool) {
        if hidden { hiddenSpotlights.insert(item.id) } else { hiddenSpotlights.remove(item.id) }
    }

    /// Drives the controller UI. Defaults to following the schedule (timeline).
    var controlMode: ControlMode = .schedule
    /// How long a temporary hold stays in effect before the schedule resumes.
    /// Chosen from the hold status sheet; shown on the hold button. Changing it
    /// re-anchors the expiry from now, matching how a thermostat re-times a hold.
    var holdDuration: HoldDuration = .oneHour {
        didSet { if controlMode == .hold { holdEndsAt = holdDuration.endDate() } }
    }
    /// Absolute time the current temporary hold expires, or nil while indefinite /
    /// not holding. Anchored when the hold begins so the "Until …" time stays put
    /// across the controller, dashboard, and status sheet instead of drifting.
    private(set) var holdEndsAt: Date? = nil

    /// Human-readable tail for "Until …" while holding: the anchored expiry time
    /// (plus the geofence auto-away option when enabled), or a resume phrase for an
    /// indefinite hold. Read by the controller footer, dashboard card, and sheet.
    var holdUntilText: String {
        guard let end = holdEndsAt else {
            return "you resume it"
        }
        let time = end.formatted(date: .omitted, time: .shortened)
        return device.geofenceEnabled ? "\(time) or Away" : time
    }
    /// The activity profile shown when `controlMode == .activity` (and as the
    /// current-period label while on a schedule).
    var activeProfile = ActivityProfile.samples[1]   // Home
    /// All activity profiles (the Presets list). Single source of truth.
    var activityProfiles: [ActivityProfile] = ActivityProfile.samples
    /// Saved profile-based schedules (the "Schedules" list, used when Use Presets is on).
    var schedules: [SchedulePreset] = SchedulePreset.samples() {
        didSet { recomputeTimeline() }
    }
    /// The schedule currently driving the controller timeline (falls back to the first).
    var selectedScheduleID: SchedulePreset.ID? {
        didSet { recomputeTimeline() }
    }
    /// Non-preset setpoint programs, one selectable list per mode (Use Presets off).
    var programs: [ScheduleKind: [ScheduleProgram]] = [
        .heat: ScheduleProgram.samples(for: .heat),
        .cool: ScheduleProgram.samples(for: .cool),
        .auto: ScheduleProgram.samples(for: .auto),
    ] {
        didSet { recomputeTimeline() }
    }
    /// The selected program per mode.
    var selectedProgramID: [ScheduleKind: ScheduleProgram.ID] = [:] {
        didSet { recomputeTimeline() }
    }
    /// HVAC service reminders shown in the Reminders tab. Single source of truth so
    /// edits persist across the session.
    var serviceReminders: [ServiceReminder] = ServiceReminder.samples()
    /// How many reminders are in the red (life below the critical threshold) — drives
    /// the notification bubble on the Reminders tab.
    var criticalReminderCount: Int { serviceReminders.filter(\.isCritical).count }
    /// The contractor on file — shared by Settings and the reminder "Call Contractor".
    var contractor: Contractor = .sample
    /// Persisted thermostat settings (Display Options, System Configuration, About,
    /// Location) so the Settings screens survive navigating away and back.
    var thermostatSettings = ThermostatSettings()

    /// The active schedule — the selected one, or the first available.
    var activeSchedule: SchedulePreset? {
        schedules.first { $0.id == selectedScheduleID } ?? schedules.first
    }

    /// Which non-preset program kind the current system mode uses (nil when off).
    private var activeKind: ScheduleKind? {
        switch device.systemMode {
        case .heat, .auxHeat: return .heat
        case .cool: return .cool
        case .auto: return .auto
        case .off: return nil
        }
    }

    /// The active non-preset program for the current mode.
    var activeProgram: ScheduleProgram? {
        guard let kind = activeKind, let list = programs[kind], !list.isEmpty else { return nil }
        return list.first { $0.id == selectedProgramID[kind] } ?? list.first
    }

    /// Name shown wherever the running schedule is referenced — the active preset
    /// schedule when Use Presets is on, otherwise the active program for the mode.
    var scheduleName: String {
        let name = device.usePresets ? activeSchedule?.name : activeProgram?.name
        return name ?? device.scheduleName
    }

    /// Today's timeline — (start minutes, period) pairs sorted by time — drawn from the
    /// active preset schedule or, when Use Presets is off, the active setpoint program.
    /// Cached: the sort/build only runs when the underlying data changes (via
    /// `recomputeTimeline()` from the input `didSet`s), not on every read. `currentPeriod`
    /// / `upcomingPeriods` derive from this cache using the live clock, which is cheap.
    private(set) var todaysTimeline: [(minutes: Int, period: TimelinePeriod)] = []

    /// Rebuild `todaysTimeline` from the active schedule/program. Called from `init`,
    /// `recomputeDevice()`, and the schedule/program input `didSet`s.
    private func recomputeTimeline() {
        let today = todayWeekdayIndex()
        if device.usePresets {
            guard let schedule = activeSchedule, !schedule.groups.isEmpty else { todaysTimeline = []; return }
            let group = schedule.groups.first { $0.days.contains(today) } ?? schedule.groups[0]
            todaysTimeline = group.events.sorted { $0.time < $1.time }
                .map { (minutesSinceMidnight($0.time), TimelinePeriod(from: $0)) }
        } else {
            guard let program = activeProgram, !program.groups.isEmpty else { todaysTimeline = []; return }
            let group = program.groups.first { $0.days.contains(today) } ?? program.groups[0]
            todaysTimeline = group.events.sorted { $0.time < $1.time }
                .map { (minutesSinceMidnight($0.time), programPeriod($0)) }
        }
    }

    /// A bare setpoint program event as a timeline period (no profile). Its start time
    /// stands in for the missing profile name so program cards don't read blank.
    private func programPeriod(_ e: ProgramEvent) -> TimelinePeriod {
        TimelinePeriod(id: e.id, name: e.timeText, symbol: "", colorHex: 0,
                       heatTo: e.heatTo, coolTo: e.coolTo, startText: e.timeText)
    }

    /// Index of the period running right now — the last one that has started; before the
    /// first start we're still in the previous day's final period. (See `TimelineMath`.)
    private var currentTimelineIndex: Int? {
        TimelineMath.currentIndex(starts: todaysTimeline.map(\.minutes), now: minutesSinceMidnight(Date()))
    }

    /// The period running right now, derived from the active schedule or program.
    var currentPeriod: TimelinePeriod? {
        guard let i = currentTimelineIndex else { return nil }
        return todaysTimeline[i].period
    }

    /// Upcoming periods — every period that still starts later today, so the pager
    /// matches the saved schedule from now to end of day (wrapping correctly before the
    /// first start, when the current period is the previous day's carryover).
    var upcomingPeriods: [TimelinePeriod] {
        let t = todaysTimeline
        return TimelineMath.upcomingIndices(starts: t.map(\.minutes), now: minutesSinceMidnight(Date())).map { t[$0].period }
    }

    /// Today's WeekDay index (0 = Monday … 6 = Sunday) from Calendar's 1=Sun…7=Sat.
    private func todayWeekdayIndex() -> Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private func minutesSinceMidnight(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Adjusts the comfort setpoint. In Auto this moves one bound of the range and,
    /// honoring the two-degree deadband, pushes the opposite bound when they'd
    /// collide. In heat/cool it moves the single active target. Adjusting while
    /// following a schedule creates a temporary hold that overrides it; adjusting a
    /// running profile (no schedule) just nudges that profile in place.
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

        if controlMode == .schedule {
            holdEndsAt = holdDuration.endDate()
            withAnimation(.snappy) { controlMode = .hold }
        }
    }

    /// Convenience for the single-device screens: adjusts the selected device.
    func adjustKeep(_ bound: SetpointBound, by delta: Int) {
        adjustKeep(bound, by: delta, in: device.id)
    }

    /// Menu/keyboard convenience: nudge the active setpoint(s) for the selected
    /// device, moving whichever bound(s) the current mode targets.
    func nudgeSetpoint(by delta: Int) {
        switch device.systemMode {
        case .heat, .auxHeat: adjustKeep(.low, by: delta)
        case .cool:           adjustKeep(.high, by: delta)
        case .auto, .off:     adjustKeep(.low, by: delta); adjustKeep(.high, by: delta)
        }
    }

    /// Activate the activity profile with the given name, if one exists (used by
    /// the menu bar's Home / Away shortcuts).
    func activateProfileNamed(_ name: String) {
        if let profile = activityProfiles.first(where: { $0.name == name }) {
            activateProfile(profile)
        }
    }

    /// Toggle whether a paired sensor feeds the averaged temperature on a device. At least
    /// one sensor must always feed the average, so deselecting the last participant is a no-op.
    func toggleSensor(_ sensor: RoomSensor, in id: Device.ID) {
        guard let di = devices.firstIndex(where: { $0.id == id }),
              let si = devices[di].sensors.firstIndex(where: { $0.id == sensor.id }) else { return }
        if devices[di].sensors[si].participating,
           devices[di].sensors.filter({ $0.participating }).count <= 1 { return }
        withAnimation(.snappy) { devices[di].sensors[si].participating.toggle() }
    }

    /// Rename a paired sensor. No-op if the name is blank/unchanged.
    func renameSensor(_ sensorID: RoomSensor.ID, to name: String, in id: Device.ID) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let di = devices.firstIndex(where: { $0.id == id }),
              let si = devices[di].sensors.firstIndex(where: { $0.id == sensorID }),
              devices[di].sensors[si].name != trimmed else { return }
        devices[di].sensors[si].name = trimmed
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

    /// Enter or leave vacation mode. When entering with an assigned profile, the
    /// device holds that profile's setpoints; otherwise it keeps its current setback.
    func setVacation(_ on: Bool, profile: ActivityProfile? = nil) {
        if on, let profile, let i = devices.firstIndex(where: { $0.id == device.id }) {
            devices[i].keepMin = profile.heatTo
            devices[i].keepMax = profile.coolTo
        }
        withAnimation(.snappy) { controlMode = on ? .vacation : .schedule }
    }

    /// Resume the schedule, clearing any hold/vacation and restoring the
    /// current scheduled period's setpoints.
    func resumeSchedule() {
        holdEndsAt = nil
        withAnimation(.snappy) { controlMode = .schedule }
        // Restore the setpoints of the schedule's current period.
        syncScheduleSetpoints()
    }

    // MARK: - Schedules

    /// Select a schedule to run and snap the current setpoints to its active period.
    func selectSchedule(_ id: SchedulePreset.ID) {
        selectedScheduleID = id
        syncScheduleSetpoints()
    }

    /// Insert a new schedule or update an existing one (matched by id); a new one
    /// becomes selected.
    func saveSchedule(_ updated: SchedulePreset) {
        if let i = schedules.firstIndex(where: { $0.id == updated.id }) {
            schedules[i] = updated
        } else {
            schedules.append(updated)
            selectedScheduleID = updated.id
        }
        if activeSchedule?.id == updated.id { syncScheduleSetpoints() }
    }

    func duplicateSchedule(_ preset: SchedulePreset) {
        guard let i = schedules.firstIndex(where: { $0.id == preset.id }) else { return }
        schedules.insert(SchedulePreset(name: preset.name + " Copy", groups: preset.groups), at: i + 1)
    }

    func deleteSchedule(_ id: SchedulePreset.ID) {
        schedules.removeAll { $0.id == id }
        if selectedScheduleID == id { selectedScheduleID = schedules.first?.id }
        syncScheduleSetpoints()
    }

    /// Push the active period's range onto the selected device's live setpoints, so the
    /// current-period card reflects the running schedule. Only while following a schedule
    /// (a hold keeps its own held value). Call on appear and when the period changes.
    func syncScheduleSetpoints() {
        guard controlMode == .schedule, let p = currentPeriod,
              let i = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[i].keepMin = p.heatTo
        devices[i].keepMax = p.coolTo
    }

    // MARK: - Programs (non-preset schedules)

    /// The program shown as selected for a mode (the chosen one, or the first).
    func activeProgramID(for kind: ScheduleKind) -> ScheduleProgram.ID? {
        selectedProgramID[kind] ?? programs[kind]?.first?.id
    }

    func selectProgram(_ id: ScheduleProgram.ID, kind: ScheduleKind) {
        selectedProgramID[kind] = id
        syncScheduleSetpoints()
    }

    func saveProgram(_ program: ScheduleProgram, kind: ScheduleKind) {
        if let i = programs[kind]?.firstIndex(where: { $0.id == program.id }) {
            programs[kind]?[i] = program
        } else {
            programs[kind, default: []].append(program)
            selectedProgramID[kind] = program.id
        }
        syncScheduleSetpoints()
    }

    func duplicateProgram(_ program: ScheduleProgram, kind: ScheduleKind) {
        guard let i = programs[kind]?.firstIndex(where: { $0.id == program.id }) else { return }
        programs[kind]?.insert(ScheduleProgram(name: program.name + " Copy", groups: program.groups), at: i + 1)
    }

    func deleteProgram(_ id: ScheduleProgram.ID, kind: ScheduleKind) {
        programs[kind]?.removeAll { $0.id == id }
        if selectedProgramID[kind] == id { selectedProgramID[kind] = programs[kind]?.first?.id }
        syncScheduleSetpoints()
    }

    // MARK: - Service reminders

    /// Insert a new reminder or update an existing one (matched by id).
    func saveReminder(_ reminder: ServiceReminder) {
        if let i = serviceReminders.firstIndex(where: { $0.id == reminder.id }) {
            serviceReminders[i] = reminder
        } else {
            serviceReminders.append(reminder)
        }
    }

    func deleteReminder(_ id: ServiceReminder.ID) {
        serviceReminders.removeAll { $0.id == id }
    }

    func deleteReminders(_ offsets: IndexSet) {
        serviceReminders.remove(atOffsets: offsets)
    }

    /// Mark a reminder serviced: reset its life and push the next-service date out.
    func completeReminder(_ id: ServiceReminder.ID) {
        guard let i = serviceReminders.firstIndex(where: { $0.id == id }) else { return }
        serviceReminders[i].lastCompleted = Date()
        serviceReminders[i].lifeRemaining = 1
        serviceReminders[i].nextService = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    }

    /// Dismisses a spotlight card. When the last card is dismissed the Spotlight area
    /// is hidden entirely.
    func dismissSpotlight(_ item: SpotlightItem) {
        withAnimation { spotlights.removeAll { $0.id == item.id } }
    }

    // MARK: - Homes

    /// Assign (or unassign) a thermostat to a home. A thermostat belongs to at
    /// most one home — assigning it here clears any previous home assignment.
    func assignDevice(_ deviceID: Device.ID, toHome homeID: Home.ID?) {
        guard let i = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[i].homeID = homeID
    }

    /// Delete homes and unassign any thermostats that were in those homes.
    func deleteHomes(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { homes[$0].id })
        for i in devices.indices where removedIDs.contains(devices[i].homeID ?? UUID()) {
            devices[i].homeID = nil
        }
        homes.remove(atOffsets: offsets)
    }

    func signIn() {
        withAnimation(.easeInOut) { route = .main }
    }

    func signOut() {
        showAccount = false
        withAnimation(.easeInOut) { route = .login }
    }

    // MARK: - Widget

    /// Writes every device's current state to the App Group UserDefaults so
    /// any configured widget can read it, and publishes the device list for the
    /// widget's thermostat picker. Preserves in-flight comfort feedback.
    func writeWidgetSnapshot() {
        let list: [WidgetDeviceInfo] = devices.map {
            WidgetDeviceInfo(id: $0.id.uuidString, name: $0.name)
        }
        WidgetSnapshot.saveDeviceList(list)

        for d in devices {
            let widgetActivity: WidgetActivity
            switch d.activity {
            case .idle:    widgetActivity = d.fanMode == .on ? .fan : .idle
            case .heating: widgetActivity = .heating
            case .cooling: widgetActivity = .cooling
            }

            let deviceID = d.id.uuidString
            var snap = WidgetSnapshot.load(deviceID: deviceID)
            // Reset feedback state when the HVAC activity changes.
            if snap.activity != widgetActivity {
                snap.feedbackGiven = false
                snap.comfortFeedback = nil
            }
            snap.deviceName  = d.name
            snap.currentTemp = d.currentTemp
            snap.humidity    = d.humidity
            snap.activity    = widgetActivity
            // The app is the source of truth — drop any optimistic guess the
            // widget wrote once the real activity is known.
            snap.optimisticActivity = nil
            snap.save()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        manageLiveActivity(for: device)
    }

    /// Estimates minutes to reach `target` from `current`, factoring in:
    /// - Outdoor temperature (cold/hot outdoor air slows heating/cooling via heat loss or gain)
    /// - HVAC system type from systemMode (gas furnace fastest; heat pump moderate; aux slowest)
    /// - Home size (larger homes slower even with proportionally larger systems, due to
    ///   greater thermal mass, wall area, and duct run length)
    ///
    /// Base rates: heating 10°F/hr, cooling 12°F/hr for a medium home on a moderate day.
    private func estimateMinutesToTemp(current: Int, target: Int, for d: Device, isHeating: Bool) -> Int {
        let delta = max(1, abs(target - current))
        let base: Double = isHeating ? 10.0 / 60.0 : 12.0 / 60.0   // °F per minute

        // Outdoor temperature penalty
        let outdoorPenalty: Double
        if isHeating {
            outdoorPenalty = min(0.4, max(0, Double(target - d.outdoorTemp)) / 100.0)
        } else {
            outdoorPenalty = min(0.3, max(0, Double(d.outdoorTemp - target)) / 100.0)
        }

        // Look up home-level settings; fall back to medium/gas defaults when unassigned.
        let home = homes.first { $0.id == d.homeID }
        let hvacFactor: Double = isHeating ? (home?.hvacSystemType.heatingFactor ?? 1.0) : 1.0

        let rate = base * (1.0 - outdoorPenalty) * hvacFactor * (home?.homeSize.rateMultiplier ?? 1.0)
        return max(1, Int((Double(delta) / rate).rounded()))
    }

    /// Starts, updates, or ends the "time to temp" Live Activity based on the
    /// selected device's current HVAC state.
    private func manageLiveActivity(for d: Device) {
        let isActive = d.activity == .heating || d.activity == .cooling
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if isActive {
            let isHeating = d.activity == .heating
            let target = isHeating ? d.keepMin : d.keepMax
            let minutes = estimateMinutesToTemp(
                current: d.currentTemp, target: target,
                for: d, isHeating: isHeating
            )
            let endDate = Date().addingTimeInterval(Double(minutes) * 60)

            let state = PetticoatActivityAttributes.ContentState(
                currentTemp: d.currentTemp,
                targetTemp: target,
                estimatedEndDate: endDate,
                isHeating: isHeating
            )

            if let activity = liveActivity, activity.activityState == .active {
                Task { await activity.update(.init(state: state, staleDate: endDate)) }
            } else {
                let attrs = PetticoatActivityAttributes(deviceName: d.name, startTemp: d.currentTemp)
                liveActivity = try? Activity.request(
                    attributes: attrs,
                    content: .init(state: state, staleDate: endDate)
                )
            }
        } else if let activity = liveActivity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
            liveActivity = nil
        }
    }

    /// Reads any pending thermostat command left by a widget interaction and
    /// applies it. Called when the app returns to the foreground. Clears the
    /// command before applying so a recomputeDevice()-triggered writeWidgetSnapshot()
    /// doesn't see stale data.
    func applyPendingWidgetCommand() {
        let deviceID = device.id.uuidString
        var snap = WidgetSnapshot.load(deviceID: deviceID)
        guard snap.pendingSetpointDelta != nil || snap.pendingFanRun == true else { return }

        let delta = snap.pendingSetpointDelta
        let runFan = snap.pendingFanRun == true
        snap.pendingSetpointDelta = nil
        snap.pendingFanRun = nil
        snap.save()

        if let delta {
            // Positive delta = user is cold → raise the heat bound.
            // Negative delta = user is warm → lower the cool bound.
            // adjustKeep ignores the bound in single-mode (heat/cool), so this
            // is correct for all system modes.
            let bound: SetpointBound = delta > 0 ? .low : .high
            adjustKeep(bound, by: delta)
        }

        if runFan, let i = devices.firstIndex(where: { $0.id == device.id }) {
            devices[i].fanMode = .on
            devices[i].fanHoldDuration = .twoHours
        }
    }
}
