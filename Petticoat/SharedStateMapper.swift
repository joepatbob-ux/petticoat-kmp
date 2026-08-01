#if canImport(PetticoatShared) && os(iOS)
import Foundation
import PetticoatShared

/// Converts Kotlin value snapshots into the existing native SwiftUI model types.
/// The conversion layer deliberately stays in iOS: SwiftUI continues to work with
/// `UUID`, `Date`, SF Symbols, and observable reference types.
enum SharedStateMapper {
    static func uuid(_ value: String?) -> UUID? {
        guard let value else { return nil }
        if let uuid = UUID(uuidString: value) { return uuid }

        // Accept IDs produced by early KMP builds (32 hex characters, no dashes).
        let hex = value.filter(\.isHexDigit)
        guard hex.count == 32 else { return nil }
        let parts = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20).prefix(12),
        ]
        return UUID(uuidString: parts.map(String.init).joined(separator: "-"))
    }

    static func requiredUUID(_ value: String) -> UUID {
        uuid(value) ?? UUID()
    }

    static func route(_ value: String) -> AppModel.Route {
        switch value {
        case "Login": .login
        case "Main": .main
        default: .splash
        }
    }

    static func deviceTab(_ value: String) -> DeviceTab {
        switch value {
        case "Schedule": .schedule
        case "Usage": .usage
        case "Reminders": .reminders
        case "Settings": .settings
        default: .control
        }
    }

    static func systemMode(_ value: String) -> SystemMode {
        switch value {
        case "Cool": .cool
        case "Heat": .heat
        case "AuxHeat": .auxHeat
        case "Off": .off
        default: .auto
        }
    }

    static func fanMode(_ value: String) -> FanMode {
        value == "On" ? .on : .auto
    }

    static func holdDuration(_ value: String) -> HoldDuration {
        switch value {
        case "OneHour": .oneHour
        case "TwoHours": .twoHours
        case "ThreeHours": .threeHours
        case "SixHours": .sixHours
        case "TwelveHours": .twelveHours
        default: .indefinite
        }
    }

    static func controlMode(_ value: String) -> ControlMode {
        switch value {
        case "Standard": .standard
        case "Hold": .hold
        case "Activity": .activity
        case "Vacation": .vacation
        default: .schedule
        }
    }

    static func appearance(_ value: String) -> AppAppearance {
        switch value {
        case "Light": .light
        case "Dark": .dark
        default: .system
        }
    }

    static func stepperStyle(_ value: String) -> StepperStyle {
        value == "Chevron" ? .chevron : .plusMinus
    }

    static func dashboardSection(_ value: String) -> DashboardSection {
        value == "Spotlight" ? .spotlight : .thermostats
    }

    static func homeSize(_ value: String) -> HomeSize {
        switch value {
        case "Small": .small
        case "Large": .large
        case "XLarge": .xlarge
        default: .medium
        }
    }

    static func hvacType(_ value: String) -> HVACSystemType {
        switch value {
        case "ElectricFurnace": .electricFurnace
        case "HeatPump": .heatPump
        case "AuxHeat": .auxHeat
        default: .gasFurnace
        }
    }

    static func temperatureUnit(_ value: String) -> TemperatureUnit {
        value == "Celsius" ? .celsius : .fahrenheit
    }

    static func scheduleKind(_ value: String) -> ScheduleKind {
        switch value {
        case "Cool": .cool
        case "Auto": .auto
        default: .heat
        }
    }

    static func reminderBasis(_ value: String) -> ReminderBasis {
        value == "Calendar" ? .calendar : .runtime
    }

    static func spotlightKind(_ value: String) -> SpotlightItem.Kind {
        switch value {
        case "Promotional": .promotional
        case "Partner": .partner
        default: .generic
        }
    }

    static func sensor(_ value: PetticoatShared.RoomSensor) -> RoomSensor {
        RoomSensor(
            id: requiredUUID(value.id),
            name: value.name,
            temp: Int(value.temp),
            humidity: Int(value.humidity),
            participating: value.participating,
            battery: value.battery?.intValue
        )
    }

    static func device(_ value: PetticoatShared.Device) -> Device {
        Device(
            id: requiredUUID(value.id),
            name: value.name,
            location: value.location,
            keepMin: Int(value.keepMin),
            keepMax: Int(value.keepMax),
            holdUntil: value.holdUntil,
            outdoorTemp: Int(value.outdoorTemp),
            outdoorHigh: Int(value.outdoorHigh),
            outdoorLow: Int(value.outdoorLow),
            scheduleName: value.scheduleName,
            sensorSummary: value.sensorSummary,
            sensors: value.sensors.map(sensor),
            systemMode: systemMode(value.systemMode.wireValue),
            fanMode: fanMode(value.fanMode.wireValue),
            fanHoldDuration: holdDuration(value.fanHoldDuration.wireValue),
            circulateFan: value.circulateFan,
            circulateAmount: value.circulateAmount,
            circulateHoldDuration: holdDuration(value.circulateHoldDuration.wireValue),
            geofenceEnabled: value.geofenceEnabled,
            usePresets: value.usePresets,
            earlyStart: value.earlyStart,
            isOffline: value.isOffline,
            offlineSince: value.offlineSince,
            homeID: uuid(value.homeId)
        )
    }

    static func home(_ value: PetticoatShared.Home) -> Home {
        Home(
            id: requiredUUID(value.id),
            name: value.name,
            homeSize: homeSize(value.homeSize.wireValue),
            hvacSystemType: hvacType(value.hvacSystemType.wireValue)
        )
    }

    static func spotlight(_ value: PetticoatShared.SpotlightItem) -> SpotlightItem {
        SpotlightItem(
            id: requiredUUID(value.id),
            kind: spotlightKind(value.kind.wireValue),
            provider: value.provider,
            title: value.title,
            body: value.body,
            validUntil: value.validUntil,
            actionLabel: value.actionLabel,
            heroImage: value.heroImage,
            startsInstall: value.startsInstall
        )
    }

    static func profile(_ value: PetticoatShared.ActivityProfile) -> ActivityProfile {
        ActivityProfile(
            id: requiredUUID(value.id),
            name: value.name,
            symbol: value.symbol,
            colorHex: UInt(value.colorHex),
            heatTo: Int(value.heatTo),
            coolTo: Int(value.coolTo),
            subtitle: value.subtitle
        )
    }

    static func scheduleEvent(_ value: PetticoatShared.ScheduleEvent) -> ScheduleEvent {
        ScheduleEvent(
            id: requiredUUID(value.id),
            name: value.name,
            symbol: value.symbol,
            colorHex: UInt(value.colorHex),
            heatTo: Int(value.heatTo),
            coolTo: Int(value.coolTo),
            time: date(minutes: Int(value.startMinutes))
        )
    }

    static func scheduleGroup(_ value: PetticoatShared.ScheduleDayGroup) -> ScheduleDayGroup {
        ScheduleDayGroup(
            id: requiredUUID(value.id),
            days: Set(value.dayNumbers.map(Int.init)),
            events: value.events.map(scheduleEvent)
        )
    }

    static func schedule(_ value: PetticoatShared.SchedulePreset) -> SchedulePreset {
        SchedulePreset(
            id: requiredUUID(value.id),
            name: value.name,
            groups: value.groups.map(scheduleGroup)
        )
    }

    static func programEvent(_ value: PetticoatShared.ProgramEvent) -> ProgramEvent {
        ProgramEvent(
            id: requiredUUID(value.id),
            time: date(minutes: Int(value.startMinutes)),
            heatTo: Int(value.heatTo),
            coolTo: Int(value.coolTo)
        )
    }

    static func programGroup(_ value: PetticoatShared.ProgramDayGroup) -> ProgramDayGroup {
        ProgramDayGroup(
            id: requiredUUID(value.id),
            days: Set(value.dayNumbers.map(Int.init)),
            events: value.events.map(programEvent)
        )
    }

    static func program(_ value: PetticoatShared.ScheduleProgram) -> ScheduleProgram {
        ScheduleProgram(
            id: requiredUUID(value.id),
            name: value.name,
            groups: value.groups.map(programGroup)
        )
    }

    static func reminder(_ value: PetticoatShared.ServiceReminder) -> ServiceReminder {
        ServiceReminder(
            id: requiredUUID(value.id),
            name: value.name,
            type: value.type,
            basedOn: reminderBasis(value.basedOn.wireValue),
            durationText: value.durationText,
            nextService: Date(timeIntervalSince1970: TimeInterval(value.nextServiceEpochMs) / 1_000),
            lastCompleted: value.lastCompletedEpochMs.map {
                Date(timeIntervalSince1970: TimeInterval(truncating: $0) / 1_000)
            },
            spec: value.spec,
            lifeRemaining: value.lifeRemaining,
            hasContractor: value.hasContractor
        )
    }

    static func timelinePeriod(_ value: PetticoatShared.TimelinePeriod) -> TimelinePeriod {
        TimelinePeriod(
            id: requiredUUID(value.id),
            name: value.name,
            symbol: value.symbol,
            colorHex: UInt(value.colorHex),
            heatTo: Int(value.heatTo),
            coolTo: Int(value.coolTo),
            startText: value.startText
        )
    }

    static func date(minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    static func minutes(_ date: Date) -> Int32 {
        let values = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Int32((values.hour ?? 0) * 60 + (values.minute ?? 0))
    }

    static func sharedProfile(_ value: ActivityProfile) -> PetticoatShared.ActivityProfile {
        PetticoatShared.SharedModelFactory.shared.profile(
            id: value.id.uuidString,
            name: value.name,
            symbol: value.symbol,
            colorHex: Int64(value.colorHex),
            heatTo: Int32(value.heatTo),
            coolTo: Int32(value.coolTo),
            subtitle: value.subtitle
        )
    }

    static func sharedScheduleEvent(_ value: ScheduleEvent) -> PetticoatShared.ScheduleEvent {
        PetticoatShared.SharedModelFactory.shared.scheduleEvent(
            id: value.id.uuidString,
            name: value.name,
            symbol: value.symbol,
            colorHex: Int64(value.colorHex),
            heatTo: Int32(value.heatTo),
            coolTo: Int32(value.coolTo),
            startMinutes: minutes(value.time)
        )
    }

    static func sharedScheduleGroup(_ value: ScheduleDayGroup) -> PetticoatShared.ScheduleDayGroup {
        PetticoatShared.SharedModelFactory.shared.scheduleGroup(
            id: value.id.uuidString,
            dayNumbers: value.days.sorted().map(Int32.init),
            events: value.events.map(sharedScheduleEvent)
        )
    }

    static func sharedSchedule(_ value: SchedulePreset) -> PetticoatShared.SchedulePreset {
        PetticoatShared.SharedModelFactory.shared.schedule(
            id: value.id.uuidString,
            name: value.name,
            groups: value.groups.map(sharedScheduleGroup)
        )
    }

    static func sharedProgramEvent(_ value: ProgramEvent) -> PetticoatShared.ProgramEvent {
        PetticoatShared.SharedModelFactory.shared.programEvent(
            id: value.id.uuidString,
            startMinutes: minutes(value.time),
            heatTo: Int32(value.heatTo),
            coolTo: Int32(value.coolTo)
        )
    }

    static func sharedProgramGroup(_ value: ProgramDayGroup) -> PetticoatShared.ProgramDayGroup {
        PetticoatShared.SharedModelFactory.shared.programGroup(
            id: value.id.uuidString,
            dayNumbers: value.days.sorted().map(Int32.init),
            events: value.events.map(sharedProgramEvent)
        )
    }

    static func sharedProgram(_ value: ScheduleProgram) -> PetticoatShared.ScheduleProgram {
        PetticoatShared.SharedModelFactory.shared.program(
            id: value.id.uuidString,
            name: value.name,
            groups: value.groups.map(sharedProgramGroup)
        )
    }

    static func sharedReminder(_ value: ServiceReminder) -> PetticoatShared.ServiceReminder {
        PetticoatShared.SharedModelFactory.shared.reminder(
            id: value.id.uuidString,
            name: value.name,
            type: value.type,
            basedOn: value.basedOn == .calendar ? "Calendar" : "Runtime",
            durationText: value.durationText,
            nextServiceEpochMs: Int64(value.nextService.timeIntervalSince1970 * 1_000),
            lastCompletedEpochMs: value.lastCompleted.map {
                Int64($0.timeIntervalSince1970 * 1_000)
            } ?? -1,
            spec: value.spec,
            lifeRemaining: value.lifeRemaining,
            hasContractor: value.hasContractor
        )
    }

    static func sharedHome(_ value: Home) -> PetticoatShared.Home {
        PetticoatShared.SharedModelFactory.shared.home(
            id: value.id.uuidString,
            name: value.name,
            homeSize: value.homeSize.sharedWireValue,
            hvacSystemType: value.hvacSystemType.sharedWireValue
        )
    }

    static func sharedContractor(_ value: Contractor) -> PetticoatShared.Contractor {
        PetticoatShared.SharedModelFactory.shared.contractor(
            company: value.company,
            address: value.address,
            phone: value.phone,
            city: value.city,
            state: value.state,
            country: value.country
        )
    }

    static func sharedSettings(_ value: ThermostatSettings) -> PetticoatShared.ThermostatSettings {
        PetticoatShared.SharedModelFactory.shared.thermostatSettings(
            continuousBacklight: value.continuousBacklight,
            displayHumidity: value.displayHumidity,
            displayTime: value.displayTime,
            units: value.units == .celsius ? "Celsius" : "Fahrenheit",
            lockThermostat: value.lockThermostat,
            coolingMin: Int32(value.coolingMin),
            heatingMax: Int32(value.heatingMax),
            humidification: value.humidification,
            humidifyTo: Int32(value.humidifyTo),
            dehumidification: value.dehumidification,
            dehumidifyTo: Int32(value.dehumidifyTo),
            coolingBoost: value.coolingBoost,
            heatingBoost: value.heatingBoost,
            auxBoost: value.auxBoost,
            temperatureOffset: Int32(value.temperatureOffset),
            humidityOffset: Int32(value.humidityOffset),
            acProtection: value.acProtection,
            name: value.name,
            locationAddress: value.locationAddress,
            locationUnit: value.locationUnit,
            locationCity: value.locationCity,
            locationState: value.locationState,
            locationZip: value.locationZip,
            locationCountry: value.locationCountry
        )
    }
}

extension DeviceTab {
    var sharedWireValue: String {
        switch self {
        case .control: "Control"
        case .schedule: "Schedule"
        case .usage: "Usage"
        case .reminders: "Reminders"
        case .settings: "Settings"
        }
    }
}

extension AppAppearance {
    var sharedWireValue: String {
        switch self {
        case .light: "Light"
        case .system: "System"
        case .dark: "Dark"
        }
    }
}

extension StepperStyle {
    var sharedWireValue: String {
        switch self {
        case .plusMinus: "PlusMinus"
        case .chevron: "Chevron"
        }
    }
}

extension HoldDuration {
    var sharedWireValue: String {
        switch self {
        case .indefinite: "Indefinite"
        case .oneHour: "OneHour"
        case .twoHours: "TwoHours"
        case .threeHours: "ThreeHours"
        case .sixHours: "SixHours"
        case .twelveHours: "TwelveHours"
        }
    }
}

extension SystemMode {
    var sharedWireValue: String {
        switch self {
        case .cool: "Cool"
        case .heat: "Heat"
        case .auxHeat: "AuxHeat"
        case .auto: "Auto"
        case .off: "Off"
        }
    }
}

extension FanMode {
    var sharedWireValue: String {
        switch self {
        case .auto: "Auto"
        case .on: "On"
        }
    }
}

extension HomeSize {
    var sharedWireValue: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .xlarge: "XLarge"
        }
    }
}

extension HVACSystemType {
    var sharedWireValue: String {
        switch self {
        case .gasFurnace: "GasFurnace"
        case .electricFurnace: "ElectricFurnace"
        case .heatPump: "HeatPump"
        case .auxHeat: "AuxHeat"
        }
    }
}

extension ScheduleKind {
    var sharedWireValue: String {
        switch self {
        case .heat: "Heat"
        case .cool: "Cool"
        case .auto: "Auto"
        }
    }
}
#endif
