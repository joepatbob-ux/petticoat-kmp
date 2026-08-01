import SwiftUI
import Observation
#if canImport(PetticoatShared) && os(iOS)
import PetticoatShared
#endif

// MARK: - Mock models

struct Device: Identifiable, Equatable {
    let id: UUID
    let name: String
    let location: String
    var keepMin: Int
    var keepMax: Int
    let holdUntil: String
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

    init(
        id: UUID = UUID(),
        name: String,
        location: String,
        keepMin: Int,
        keepMax: Int,
        holdUntil: String,
        outdoorTemp: Int,
        outdoorHigh: Int,
        outdoorLow: Int,
        scheduleName: String,
        sensorSummary: String,
        sensors: [RoomSensor] = RoomSensor.samples,
        systemMode: SystemMode = .auto,
        fanMode: FanMode = .auto,
        fanHoldDuration: HoldDuration = .indefinite,
        circulateFan: Bool = true,
        circulateAmount: String = "33% (15min)",
        circulateHoldDuration: HoldDuration = .indefinite,
        geofenceEnabled: Bool = true,
        usePresets: Bool = true,
        earlyStart: Bool = true,
        isOffline: Bool = false,
        offlineSince: String? = nil,
        homeID: Home.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.keepMin = keepMin
        self.keepMax = keepMax
        self.holdUntil = holdUntil
        self.outdoorTemp = outdoorTemp
        self.outdoorHigh = outdoorHigh
        self.outdoorLow = outdoorLow
        self.scheduleName = scheduleName
        self.sensorSummary = sensorSummary
        self.sensors = sensors
        self.systemMode = systemMode
        self.fanMode = fanMode
        self.fanHoldDuration = fanHoldDuration
        self.circulateFan = circulateFan
        self.circulateAmount = circulateAmount
        self.circulateHoldDuration = circulateHoldDuration
        self.geofenceEnabled = geofenceEnabled
        self.usePresets = usePresets
        self.earlyStart = earlyStart
        self.isOffline = isOffline
        self.offlineSince = offlineSince
        self.homeID = homeID
    }

    /// Averaged temperature across all participating sensors.
    var currentTemp: Int {
        let active = sensors.filter(\.participating)
        guard !active.isEmpty else { return 0 }
        return active.map(\.temp).reduce(0, +) / active.count
    }

    /// Averaged humidity across all participating sensors.
    var humidity: Int {
        let active = sensors.filter(\.participating)
        guard !active.isEmpty else { return 0 }
        return active.map(\.humidity).reduce(0, +) / active.count
    }

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
        keepMin: 62,
        keepMax: 73,
        holdUntil: "6:00AM or Away",
        outdoorTemp: 89,
        outdoorHigh: 89,
        outdoorLow: 81,
        scheduleName: "Comfort",
        sensorSummary: "2 of 3 Sensors"
    )

    static let sampleUpstairs = Device(
        name: "Upstairs",
        location: "St. Louis, MO",
        keepMin: 66,
        keepMax: 76,
        holdUntil: "6:00AM or Away",
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
    let id: UUID
    var name: String
    let temp: Int
    let humidity: Int
    var participating: Bool
    var battery: Int? = nil

    init(
        id: UUID = UUID(),
        name: String,
        temp: Int,
        humidity: Int,
        participating: Bool,
        battery: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.temp = temp
        self.humidity = humidity
        self.participating = participating
        self.battery = battery
    }

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

    let id: UUID
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

    init(
        id: UUID = UUID(),
        kind: Kind = .generic,
        provider: String,
        title: String,
        body: String,
        validUntil: String = "",
        actionLabel: String? = nil,
        heroImage: String? = nil,
        startsInstall: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.provider = provider
        self.title = title
        self.body = body
        self.validUntil = validUntil
        self.actionLabel = actionLabel
        self.heroImage = heroImage
        self.startsInstall = startsInstall
    }

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
    private var isApplyingSharedState = false

    #if canImport(PetticoatShared) && os(iOS)
    /// Canonical domain model. This Swift type is now an observation/binding facade.
    private let sharedModel = PetticoatShared.SharedAppModelFactory.shared.create()
    private var sharedObservationTask: Task<Void, Never>?
    #endif

    private let widgetSyncService = WidgetSyncService()

    /// All paired thermostats, shown as resortable cards on the dashboard. Empty
    /// means no thermostat has been added yet (the dashboard shows the onboarding
    /// welcome card instead).
    var devices: [Device] = [.sample, .sampleUpstairs] {
        didSet { if !isApplyingSharedState { recomputeDevice() } }
    }
    /// The device the single-device screens (Control, Mode, Schedule) act on.
    var selectedDeviceID: Device.ID? = nil {
        didSet { if !isApplyingSharedState { recomputeDevice() } }
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
        installNativeChangeObservers()
        startSharedObservation()
    }

    deinit {
        #if canImport(PetticoatShared) && os(iOS)
        sharedObservationTask?.cancel()
        #endif
    }

    private func startSharedObservation() {
        #if canImport(PetticoatShared) && os(iOS)
        let shared = sharedModel
        sharedObservationTask = Task { [weak self, shared] in
            for await state in shared.state {
                guard !Task.isCancelled else { return }
                await self?.applySharedState(state)
            }
        }
        #endif
    }

    private func installNativeChangeObservers() {
        contractor.onChange = { [weak self] in self?.persistContractor() }
        thermostatSettings.onChange = { [weak self] in self?.persistThermostatSettings() }
    }

    private func persistContractor() {
        guard !isApplyingSharedState else { return }
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setContractor(v: SharedStateMapper.sharedContractor(contractor))
        #endif
    }

    private func persistThermostatSettings() {
        guard !isApplyingSharedState else { return }
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setThermostatSettings(v: SharedStateMapper.sharedSettings(thermostatSettings))
        #endif
    }

    #if canImport(PetticoatShared) && os(iOS)
    @MainActor
    private func applySharedState(_ state: PetticoatShared.AppState) {
        isApplyingSharedState = true
        defer {
            isApplyingSharedState = false
            recomputeDevice()
        }

        route = SharedStateMapper.route(state.route.wireValue)
        showAccount = state.showAccount
        showAddDevice = state.showAddDevice
        showHelp = state.showHelp
        selectedTab = SharedStateMapper.deviceTab(state.selectedTab.wireValue)
        sidebarVisible = state.sidebarVisible
        addingReminder = state.addingReminder

        devices = state.devices.map(SharedStateMapper.device)
        selectedDeviceID = SharedStateMapper.uuid(state.selectedDeviceId)
        spotlights = state.spotlights.map(SharedStateMapper.spotlight)
        hiddenSpotlights = Set(state.hiddenSpotlights.compactMap(SharedStateMapper.uuid))
        dashboardSectionOrder = state.dashboardSectionOrder.map {
            SharedStateMapper.dashboardSection($0.wireValue)
        }
        showSensorsOnDashboard = state.showSensorsOnDashboard
        appearance = SharedStateMapper.appearance(state.appearance.wireValue)
        showWeatherLocation = state.showWeatherLocation
        stepperStyle = SharedStateMapper.stepperStyle(state.stepperStyle.wireValue)
        homes = state.homes.map(SharedStateMapper.home)

        controlMode = SharedStateMapper.controlMode(state.controlMode.wireValue)
        holdDuration = SharedStateMapper.holdDuration(state.holdDuration.wireValue)
        holdEndsAt = state.holdEndsAtEpochMs.map {
            Date(timeIntervalSince1970: TimeInterval(truncating: $0) / 1_000)
        }
        activeProfile = SharedStateMapper.profile(state.activeProfile)
        activityProfiles = state.activityProfiles.map(SharedStateMapper.profile)
        schedules = state.schedules.map(SharedStateMapper.schedule)
        selectedScheduleID = SharedStateMapper.uuid(state.selectedScheduleId)

        programs = [
            .heat: state.heatPrograms.map(SharedStateMapper.program),
            .cool: state.coolPrograms.map(SharedStateMapper.program),
            .auto: state.autoPrograms.map(SharedStateMapper.program),
        ]
        selectedProgramID = [
            .heat: SharedStateMapper.uuid(state.selectedHeatProgramId),
            .cool: SharedStateMapper.uuid(state.selectedCoolProgramId),
            .auto: SharedStateMapper.uuid(state.selectedAutoProgramId),
        ].compactMapValues { $0 }

        serviceReminders = state.serviceReminders.map(SharedStateMapper.reminder)
        copyContractor(from: state.contractor)
        copySettings(from: state.thermostatSettings)
        todaysTimeline = state.todaysTimeline.map {
            (Int($0.minutes), SharedStateMapper.timelinePeriod($0.period))
        }
    }

    private func copyContractor(from value: PetticoatShared.Contractor) {
        contractor.company = value.company
        contractor.address = value.address
        contractor.phone = value.phone
        contractor.city = value.city
        contractor.state = value.state
        contractor.country = value.country
    }

    private func copySettings(from value: PetticoatShared.ThermostatSettings) {
        thermostatSettings.continuousBacklight = value.continuousBacklight
        thermostatSettings.displayHumidity = value.displayHumidity
        thermostatSettings.displayTime = value.displayTime
        thermostatSettings.units = SharedStateMapper.temperatureUnit(value.units.wireValue)
        thermostatSettings.lockThermostat = value.lockThermostat
        thermostatSettings.coolingMin = Int(value.coolingMin)
        thermostatSettings.heatingMax = Int(value.heatingMax)
        thermostatSettings.humidification = value.humidification
        thermostatSettings.humidifyTo = Int(value.humidifyTo)
        thermostatSettings.dehumidification = value.dehumidification
        thermostatSettings.dehumidifyTo = Int(value.dehumidifyTo)
        thermostatSettings.coolingBoost = value.coolingBoost
        thermostatSettings.heatingBoost = value.heatingBoost
        thermostatSettings.auxBoost = value.auxBoost
        thermostatSettings.temperatureOffset = Int(value.temperatureOffset)
        thermostatSettings.humidityOffset = Int(value.humidityOffset)
        thermostatSettings.acProtection = value.acProtection
        thermostatSettings.name = value.name
        thermostatSettings.locationAddress = value.locationAddress
        thermostatSettings.locationUnit = value.locationUnit
        thermostatSettings.locationCity = value.locationCity
        thermostatSettings.locationState = value.locationState
        thermostatSettings.locationZip = value.locationZip
        thermostatSettings.locationCountry = value.locationCountry
    }
    #endif

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

    /// Write-through projection keyed by an explicit device ID. Used by ModeSheet so it
    /// can bind to a specific card's device without requiring `selectDevice` to be called
    /// first — avoiding the model cascade that can dismiss the sheet on first open.
    subscript<Value>(deviceID id: Device.ID, _ keyPath: WritableKeyPath<Device, Value>) -> Value {
        get { (devices.first { $0.id == id } ?? device)[keyPath: keyPath] }
        set {
            guard let i = devices.firstIndex(where: { $0.id == id }) else { return }
            devices[i][keyPath: keyPath] = newValue
        }
    }

    /// Make a device the target of the single-device screens.
    func selectDevice(_ id: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.selectDevice(id: id.uuidString)
        #else
        selectedDeviceID = id
        #endif
    }

    func finishSplash() {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.finishSplash()
        #else
        route = .login
        #endif
    }

    func setShowAccount(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setShowAccount(v: value)
        #else
        showAccount = value
        #endif
    }

    func setShowAddDevice(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setShowAddDevice(v: value)
        #else
        showAddDevice = value
        #endif
    }

    func setShowHelp(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setShowHelp(v: value)
        #else
        showHelp = value
        #endif
    }

    func setSelectedTab(_ value: DeviceTab) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setSelectedTabWire(value: value.sharedWireValue)
        #else
        selectedTab = value
        #endif
    }

    func setSidebarVisible(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setSidebarVisible(v: value)
        #else
        sidebarVisible = value
        #endif
    }

    func setAddingReminder(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setAddingReminder(v: value)
        #else
        addingReminder = value
        #endif
    }

    func setAppearance(_ value: AppAppearance) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setAppearanceWire(value: value.sharedWireValue)
        #else
        appearance = value
        #endif
    }

    func setShowWeatherLocation(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setShowWeatherLocation(v: value)
        #else
        showWeatherLocation = value
        #endif
    }

    func setShowSensorsOnDashboard(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setShowSensorsOnDashboard(v: value)
        #else
        showSensorsOnDashboard = value
        #endif
    }

    func setStepperStyle(_ value: StepperStyle) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setStepperStyleWire(value: value.sharedWireValue)
        #else
        stepperStyle = value
        #endif
    }

    func setHoldDuration(_ value: HoldDuration) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setHoldDurationWire(value: value.sharedWireValue)
        #else
        holdDuration = value
        #endif
    }

    func setSystemMode(_ value: SystemMode, for deviceID: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setSystemModeWire(value: value.sharedWireValue, deviceId: deviceID.uuidString)
        #else
        self[deviceID: deviceID, \.systemMode] = value
        #endif
    }

    func setFanMode(_ value: FanMode, for deviceID: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setFanModeWire(value: value.sharedWireValue, deviceId: deviceID.uuidString)
        #else
        self[deviceID: deviceID, \.fanMode] = value
        #endif
    }

    func setFanHoldDuration(_ value: HoldDuration, for deviceID: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceFanHoldDurationWire(
            value: value.sharedWireValue,
            deviceId: deviceID.uuidString
        )
        #else
        self[deviceID: deviceID, \.fanHoldDuration] = value
        #endif
    }

    func setCirculateFan(_ value: Bool, for deviceID: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceCirculateFan(v: value, deviceId: deviceID.uuidString)
        #else
        self[deviceID: deviceID, \.circulateFan] = value
        #endif
    }

    func setCirculateAmount(_ value: String, for deviceID: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceCirculateAmount(v: value, deviceId: deviceID.uuidString)
        #else
        self[deviceID: deviceID, \.circulateAmount] = value
        #endif
    }

    func setCirculateHoldDuration(_ value: HoldDuration, for deviceID: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceCirculateHoldDurationWire(
            value: value.sharedWireValue,
            deviceId: deviceID.uuidString
        )
        #else
        self[deviceID: deviceID, \.circulateHoldDuration] = value
        #endif
    }

    func setUsePresets(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceUsePresets(v: value, deviceId: device.id.uuidString)
        #else
        self[device: \.usePresets] = value
        #endif
    }

    func setEarlyStart(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceEarlyStart(v: value, deviceId: device.id.uuidString)
        #else
        self[device: \.earlyStart] = value
        #endif
    }

    func setGeofenceEnabled(_ value: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setDeviceGeofenceEnabled(v: value, deviceId: device.id.uuidString)
        #else
        self[device: \.geofenceEnabled] = value
        #endif
    }

    /// Bring the selected thermostat back online after a successful Wi-Fi reconnect,
    /// clearing the offline card and its "offline since" timestamp.
    func markSelectedDeviceOnline() {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.markSelectedDeviceOnline()
        return
        #endif
        guard let i = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[i].isOffline = false
        devices[i].offlineSince = nil
    }

    /// Reorder the dashboard thermostat cards (from the Organize Dashboard screen).
    func moveDevices(from source: IndexSet, to destination: Int) {
        #if canImport(PetticoatShared) && os(iOS)
        guard let first = source.first else { return }
        sharedModel.moveDevices(fromIndex: Int32(first), toIndex: Int32(destination))
        return
        #endif
        devices.move(fromOffsets: source, toOffset: destination)
    }

    /// Reorder the spotlight cards.
    func moveSpotlights(from source: IndexSet, to destination: Int) {
        #if canImport(PetticoatShared) && os(iOS)
        guard let first = source.first else { return }
        sharedModel.moveSpotlights(fromIndex: Int32(first), toIndex: Int32(destination))
        return
        #endif
        spotlights.move(fromOffsets: source, toOffset: destination)
    }

    /// Reorder the dashboard sections themselves.
    func moveDashboardSections(from source: IndexSet, to destination: Int) {
        #if canImport(PetticoatShared) && os(iOS)
        guard let first = source.first else { return }
        sharedModel.moveDashboardSections(fromIndex: Int32(first), toIndex: Int32(destination))
        return
        #endif
        dashboardSectionOrder.move(fromOffsets: source, toOffset: destination)
    }

    /// Show or hide a spotlight card on the dashboard (reversible).
    func setSpotlight(_ item: SpotlightItem, hidden: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setSpotlightHidden(itemId: item.id.uuidString, hidden: hidden)
        return
        #endif
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
        didSet { if !isApplyingSharedState { recomputeTimeline() } }
    }
    /// The schedule currently driving the controller timeline (falls back to the first).
    var selectedScheduleID: SchedulePreset.ID? {
        didSet { if !isApplyingSharedState { recomputeTimeline() } }
    }
    /// Non-preset setpoint programs, one selectable list per mode (Use Presets off).
    var programs: [ScheduleKind: [ScheduleProgram]] = [
        .heat: ScheduleProgram.samples(for: .heat),
        .cool: ScheduleProgram.samples(for: .cool),
        .auto: ScheduleProgram.samples(for: .auto),
    ] {
        didSet { if !isApplyingSharedState { recomputeTimeline() } }
    }
    /// The selected program per mode.
    var selectedProgramID: [ScheduleKind: ScheduleProgram.ID] = [:] {
        didSet { if !isApplyingSharedState { recomputeTimeline() } }
    }
    /// HVAC service reminders shown in the Reminders tab. Single source of truth so
    /// edits persist across the session.
    var serviceReminders: [ServiceReminder] = ServiceReminder.samples()
    /// How many reminders are in the red (life below the critical threshold) — drives
    /// the notification bubble on the Reminders tab.
    var criticalReminderCount: Int { serviceReminders.filter(\.isCritical).count }
    /// The contractor on file — shared by Settings and the reminder "Call Contractor".
    var contractor: Contractor = .sample {
        didSet {
            installNativeChangeObservers()
            persistContractor()
        }
    }
    /// Persisted thermostat settings (Display Options, System Configuration, About,
    /// Location) so the Settings screens survive navigating away and back.
    var thermostatSettings = ThermostatSettings() {
        didSet {
            installNativeChangeObservers()
            persistThermostatSettings()
        }
    }
    var tempUnit: TemperatureUnit { thermostatSettings.units }

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
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.adjustKeepWire(
            bound: bound == .low ? "Low" : "High",
            delta: Int32(delta),
            deviceId: id.uuidString
        )
        return
        #endif
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
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.nudgeSetpoint(delta: Int32(delta))
        return
        #endif
        switch device.systemMode {
        case .heat, .auxHeat: adjustKeep(.low, by: delta)
        case .cool:           adjustKeep(.high, by: delta)
        case .auto, .off:     adjustKeep(.low, by: delta); adjustKeep(.high, by: delta)
        }
    }

    /// Activate the activity profile with the given name, if one exists (used by
    /// the menu bar's Home / Away shortcuts).
    func activateProfileNamed(_ name: String) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.activateProfileNamed(name: name)
        return
        #endif
        if let profile = activityProfiles.first(where: { $0.name == name }) {
            activateProfile(profile)
        }
    }

    /// Toggle whether a paired sensor feeds the averaged temperature on a device. At least
    /// one sensor must always feed the average, so deselecting the last participant is a no-op.
    func toggleSensor(_ sensor: RoomSensor, in id: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.toggleSensor(sensorId: sensor.id.uuidString, deviceId: id.uuidString)
        return
        #endif
        guard let di = devices.firstIndex(where: { $0.id == id }),
              let si = devices[di].sensors.firstIndex(where: { $0.id == sensor.id }) else { return }
        if devices[di].sensors[si].participating,
           devices[di].sensors.filter({ $0.participating }).count <= 1 { return }
        withAnimation(.snappy) { devices[di].sensors[si].participating.toggle() }
    }

    /// Rename a paired sensor. No-op if the name is blank/unchanged.
    func renameSensor(_ sensorID: RoomSensor.ID, to name: String, in id: Device.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.renameSensor(sensorId: sensorID.uuidString, name: name, deviceId: id.uuidString)
        return
        #endif
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let di = devices.firstIndex(where: { $0.id == id }),
              let si = devices[di].sensors.firstIndex(where: { $0.id == sensorID }),
              devices[di].sensors[si].name != trimmed else { return }
        devices[di].sensors[si].name = trimmed
    }

    /// Automation Schedule/Off toggle drives schedule vs. standard control.
    func setScheduleEnabled(_ enabled: Bool) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.setScheduleEnabled(enabled: enabled)
        return
        #endif
        withAnimation(.snappy) { controlMode = enabled ? .schedule : .standard }
    }

    /// Activate an activity profile as the current controller mode.
    func activateProfile(_ profile: ActivityProfile) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.activateProfileById(id: profile.id.uuidString)
        return
        #endif
        activeProfile = profile
        withAnimation(.snappy) { controlMode = .activity }
    }

    /// Insert a new profile or update an existing one (matched by id).
    func saveProfile(_ updated: ActivityProfile) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.saveProfile(updated: SharedStateMapper.sharedProfile(updated))
        return
        #endif
        if let i = activityProfiles.firstIndex(where: { $0.id == updated.id }) {
            activityProfiles[i] = updated
        } else {
            activityProfiles.append(updated)
        }
        if activeProfile.id == updated.id { activeProfile = updated }
    }

    func duplicateProfile(_ profile: ActivityProfile) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.duplicateProfileById(id: profile.id.uuidString)
        return
        #endif
        guard let i = activityProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let copy = ActivityProfile(name: profile.name + " Copy", symbol: profile.symbol, colorHex: profile.colorHex,
                                   heatTo: profile.heatTo, coolTo: profile.coolTo, subtitle: profile.subtitle)
        activityProfiles.insert(copy, at: i + 1)
    }

    func deleteProfile(_ profile: ActivityProfile) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.deleteProfile(profileId: profile.id.uuidString)
        return
        #endif
        activityProfiles.removeAll { $0.id == profile.id }
    }

    /// Enter or leave vacation mode. When entering with an assigned profile, the
    /// device holds that profile's setpoints; otherwise it keeps its current setback.
    func setVacation(_ on: Bool, profile: ActivityProfile? = nil) {
        #if canImport(PetticoatShared) && os(iOS)
        if let profile {
            sharedModel.setVacation(on: on, profile: SharedStateMapper.sharedProfile(profile))
        } else {
            sharedModel.setVacation(on: on, profile: nil)
        }
        return
        #endif
        if on, let profile, let i = devices.firstIndex(where: { $0.id == device.id }) {
            devices[i].keepMin = profile.heatTo
            devices[i].keepMax = profile.coolTo
        }
        withAnimation(.snappy) { controlMode = on ? .vacation : .schedule }
    }

    /// Resume the schedule, clearing any hold/vacation and restoring the
    /// current scheduled period's setpoints.
    func resumeSchedule() {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.resumeSchedule()
        return
        #endif
        holdEndsAt = nil
        withAnimation(.snappy) { controlMode = .schedule }
        // Restore the setpoints of the schedule's current period.
        syncScheduleSetpoints()
    }

    // MARK: - Schedules

    /// Select a schedule to run and snap the current setpoints to its active period.
    func selectSchedule(_ id: SchedulePreset.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.selectSchedule(id: id.uuidString)
        return
        #endif
        selectedScheduleID = id
        syncScheduleSetpoints()
    }

    /// Insert a new schedule or update an existing one (matched by id); a new one
    /// becomes selected.
    func saveSchedule(_ updated: SchedulePreset) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.saveSchedule(updated: SharedStateMapper.sharedSchedule(updated))
        return
        #endif
        if let i = schedules.firstIndex(where: { $0.id == updated.id }) {
            schedules[i] = updated
        } else {
            schedules.append(updated)
            selectedScheduleID = updated.id
        }
        if activeSchedule?.id == updated.id { syncScheduleSetpoints() }
    }

    func duplicateSchedule(_ preset: SchedulePreset) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.duplicateScheduleById(id: preset.id.uuidString)
        return
        #endif
        guard let i = schedules.firstIndex(where: { $0.id == preset.id }) else { return }
        let base = preset.name + " (Copy)"
        let taken = Set(schedules.map(\.name))
        var candidate = base
        var n = 2
        while taken.contains(candidate) {
            candidate = "\(base) \(n)"
            n += 1
        }
        schedules.insert(SchedulePreset(name: candidate, groups: preset.groups), at: i + 1)
    }

    func deleteSchedule(_ id: SchedulePreset.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.deleteSchedule(id: id.uuidString)
        return
        #endif
        schedules.removeAll { $0.id == id }
        if selectedScheduleID == id { selectedScheduleID = schedules.first?.id }
        syncScheduleSetpoints()
    }

    /// Push the active period's range onto the selected device's live setpoints, so the
    /// current-period card reflects the running schedule. Only while following a schedule
    /// (a hold keeps its own held value). Call on appear and when the period changes.
    func syncScheduleSetpoints() {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.syncScheduleSetpoints()
        return
        #endif
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
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.selectProgramWire(id: id.uuidString, kind: kind.sharedWireValue)
        return
        #endif
        selectedProgramID[kind] = id
        syncScheduleSetpoints()
    }

    func saveProgram(_ program: ScheduleProgram, kind: ScheduleKind) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.saveProgramWire(
            program: SharedStateMapper.sharedProgram(program),
            kind: kind.sharedWireValue
        )
        return
        #endif
        if let i = programs[kind]?.firstIndex(where: { $0.id == program.id }) {
            programs[kind]?[i] = program
        } else {
            programs[kind, default: []].append(program)
            selectedProgramID[kind] = program.id
        }
        syncScheduleSetpoints()
    }

    func duplicateProgram(_ program: ScheduleProgram, kind: ScheduleKind) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.duplicateProgramById(id: program.id.uuidString, kind: kind.sharedWireValue)
        return
        #endif
        guard let i = programs[kind]?.firstIndex(where: { $0.id == program.id }) else { return }
        programs[kind]?.insert(ScheduleProgram(name: program.name + " Copy", groups: program.groups), at: i + 1)
    }

    func deleteProgram(_ id: ScheduleProgram.ID, kind: ScheduleKind) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.deleteProgramWire(id: id.uuidString, kind: kind.sharedWireValue)
        return
        #endif
        programs[kind]?.removeAll { $0.id == id }
        if selectedProgramID[kind] == id { selectedProgramID[kind] = programs[kind]?.first?.id }
        syncScheduleSetpoints()
    }

    // MARK: - Service reminders

    /// Insert a new reminder or update an existing one (matched by id).
    func saveReminder(_ reminder: ServiceReminder) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.saveReminder(reminder: SharedStateMapper.sharedReminder(reminder))
        return
        #endif
        if let i = serviceReminders.firstIndex(where: { $0.id == reminder.id }) {
            serviceReminders[i] = reminder
        } else {
            serviceReminders.append(reminder)
        }
    }

    func deleteReminder(_ id: ServiceReminder.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.deleteReminder(id: id.uuidString)
        return
        #endif
        serviceReminders.removeAll { $0.id == id }
    }

    func deleteReminders(_ offsets: IndexSet) {
        #if canImport(PetticoatShared) && os(iOS)
        let ids = offsets.compactMap { serviceReminders.indices.contains($0) ? serviceReminders[$0].id.uuidString : nil }
        sharedModel.deleteReminders(ids: ids)
        return
        #endif
        serviceReminders.remove(atOffsets: offsets)
    }

    /// Mark a reminder serviced: reset its life and push the next-service date out.
    func completeReminder(_ id: ServiceReminder.ID) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.completeReminder(id: id.uuidString)
        return
        #endif
        guard let i = serviceReminders.firstIndex(where: { $0.id == id }) else { return }
        serviceReminders[i].lastCompleted = Date()
        serviceReminders[i].lifeRemaining = 1
        serviceReminders[i].nextService = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    }

    /// Dismisses a spotlight card. When the last card is dismissed the Spotlight area
    /// is hidden entirely.
    func dismissSpotlight(_ item: SpotlightItem) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.dismissSpotlight(itemId: item.id.uuidString)
        return
        #endif
        withAnimation { spotlights.removeAll { $0.id == item.id } }
    }

    // MARK: - Homes

    /// Assign (or unassign) a thermostat to a home. A thermostat belongs to at
    /// most one home — assigning it here clears any previous home assignment.
    func assignDevice(_ deviceID: Device.ID, toHome homeID: Home.ID?) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.assignDevice(
            deviceId: deviceID.uuidString,
            homeId: homeID?.uuidString
        )
        return
        #endif
        guard let i = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[i].homeID = homeID
    }

    func addHome(_ home: Home) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.addHome(home: SharedStateMapper.sharedHome(home))
        #else
        homes.append(home)
        #endif
    }

    func updateHome(_ home: Home) {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.updateHome(home: SharedStateMapper.sharedHome(home))
        #else
        guard let index = homes.firstIndex(where: { $0.id == home.id }) else { return }
        homes[index] = home
        #endif
    }

    /// Delete homes and unassign any thermostats that were in those homes.
    func deleteHomes(at offsets: IndexSet) {
        #if canImport(PetticoatShared) && os(iOS)
        let ids = offsets.compactMap { homes.indices.contains($0) ? homes[$0].id.uuidString : nil }
        sharedModel.deleteHomes(ids: ids)
        return
        #endif
        let removedIDs = Set(offsets.map { homes[$0].id })
        for i in devices.indices where removedIDs.contains(devices[i].homeID ?? UUID()) {
            devices[i].homeID = nil
        }
        homes.remove(atOffsets: offsets)
    }

    func signIn() {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.signIn()
        return
        #endif
        withAnimation(.easeInOut) { route = .main }
    }

    func signOut() {
        #if canImport(PetticoatShared) && os(iOS)
        sharedModel.signOut()
        return
        #endif
        showAccount = false
        withAnimation(.easeInOut) { route = .login }
    }

    // MARK: - Widget

    func writeWidgetSnapshot() {
        widgetSyncService.sync(devices: devices, selectedDevice: device, homes: homes)
    }

    func applyPendingWidgetCommand() {
        widgetSyncService.applyPendingCommand(to: self)
    }
}
