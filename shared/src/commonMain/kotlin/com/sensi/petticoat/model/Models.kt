package com.sensi.petticoat.model

data class RoomSensor(
    val id: String = newId(),
    var name: String,
    val temp: Int,
    val humidity: Int,
    var participating: Boolean,
    val battery: Int? = null,
) {
    companion object {
        fun samples(): List<RoomSensor> = listOf(
            RoomSensor(name = "Thermostat", temp = 72, humidity = 40, participating = true),
            RoomSensor(name = "Bedroom", temp = 70, humidity = 42, participating = true, battery = 41),
            RoomSensor(name = "Office", temp = 75, humidity = 38, participating = false, battery = 12),
        )
    }
}

data class Device(
    val id: String = newId(),
    val name: String,
    val location: String,
    var keepMin: Int,
    var keepMax: Int,
    val holdUntil: String,
    val outdoorTemp: Int,
    val outdoorHigh: Int,
    val outdoorLow: Int,
    val scheduleName: String,
    val sensorSummary: String,
    var sensors: List<RoomSensor> = RoomSensor.samples(),
    var systemMode: SystemMode = SystemMode.Auto,
    var fanMode: FanMode = FanMode.Auto,
    var fanHoldDuration: HoldDuration = HoldDuration.Indefinite,
    var circulateFan: Boolean = true,
    var circulateAmount: String = "33% (15min)",
    var circulateHoldDuration: HoldDuration = HoldDuration.Indefinite,
    var geofenceEnabled: Boolean = true,
    var usePresets: Boolean = true,
    var earlyStart: Boolean = true,
    var isOffline: Boolean = false,
    var offlineSince: String? = null,
    var homeId: String? = null,
) {
    val currentTemp: Int
        get() {
            val active = sensors.filter { it.participating }
            if (active.isEmpty()) return 0
            return active.sumOf { it.temp } / active.size
        }

    val humidity: Int
        get() {
            val active = sensors.filter { it.participating }
            if (active.isEmpty()) return 0
            return active.sumOf { it.humidity } / active.size
        }

    val activity: HVACActivity
        get() = when (systemMode) {
            SystemMode.Off -> HVACActivity.Idle
            SystemMode.Cool -> if (currentTemp > keepMax) HVACActivity.Cooling else HVACActivity.Idle
            SystemMode.Heat, SystemMode.AuxHeat ->
                if (currentTemp < keepMin) HVACActivity.Heating else HVACActivity.Idle
            SystemMode.Auto -> when {
                currentTemp < keepMin -> HVACActivity.Heating
                currentTemp > keepMax -> HVACActivity.Cooling
                else -> HVACActivity.Idle
            }
        }

    val participatingCount: Int get() = sensors.count { it.participating }

    companion object {
        fun sample(): Device = Device(
            name = "Home",
            location = "St. Louis, MO",
            keepMin = 62,
            keepMax = 73,
            holdUntil = "6:00AM or Away",
            outdoorTemp = 89,
            outdoorHigh = 89,
            outdoorLow = 81,
            scheduleName = "Comfort",
            sensorSummary = "2 of 3 Sensors",
        )

        fun sampleUpstairs(): Device = Device(
            name = "Upstairs",
            location = "St. Louis, MO",
            keepMin = 66,
            keepMax = 76,
            holdUntil = "6:00AM or Away",
            outdoorTemp = 89,
            outdoorHigh = 89,
            outdoorLow = 81,
            scheduleName = "Comfort",
            sensorSummary = "1 of 2 Sensors",
            sensors = listOf(
                RoomSensor(name = "Thermostat", temp = 74, humidity = 44, participating = true),
                RoomSensor(name = "Nursery", temp = 72, humidity = 46, participating = false, battery = 63),
            ),
            isOffline = true,
            offlineSince = "4:00PM November 24, 2023",
        )
    }
}

data class Home(
    val id: String = newId(),
    var name: String,
    var homeSize: HomeSize = HomeSize.Medium,
    var hvacSystemType: HVACSystemType = HVACSystemType.GasFurnace,
)

data class SpotlightItem(
    val id: String = newId(),
    var kind: SpotlightKind = SpotlightKind.Generic,
    val provider: String,
    val title: String,
    val body: String,
    var validUntil: String = "",
    var actionLabel: String? = null,
    var heroImage: String? = null,
    var startsInstall: Boolean = false,
) {
    val subline: String get() = if (validUntil.isEmpty()) "" else "Expires: $validUntil"

    companion object {
        fun welcome(): SpotlightItem = SpotlightItem(
            kind = SpotlightKind.Promotional,
            provider = "",
            title = "Welcome to the Sensi!",
            body = "Let’s get started by installing your Sensi Thermostat.",
            startsInstall = true,
        )

        fun samples(): List<SpotlightItem> = listOf(
            SpotlightItem(
                kind = SpotlightKind.Promotional,
                provider = "",
                title = "Get more from your Sensi",
                body = "Explore Smart Alerts, energy insights, and remote room sensors.",
                validUntil = "June 27, 2024",
            ),
            SpotlightItem(
                kind = SpotlightKind.Partner,
                provider = "ACME POWER",
                title = "Save with the EcoSmart program!",
                body = "Optimize your energy usage by registering to the EcoSmart program today!",
                validUntil = "July 15, 2025",
            ),
            SpotlightItem(
                kind = SpotlightKind.Generic,
                provider = "SENSI",
                title = "Your July usage report is ready",
                body = "See how your energy use compared to last month and get personalized tips to save.",
                validUntil = "August 1, 2025",
            ),
        )
    }
}

data class ActivityProfile(
    val id: String = newId(),
    var name: String,
    var symbol: String,
    var colorHex: Long,
    var heatTo: Int,
    var coolTo: Int,
    var subtitle: String,
) {
    val rangeText: String get() = "$heatTo · $coolTo"

    companion object {
        fun samples(): List<ActivityProfile> = listOf(
            ActivityProfile(name = "Away", symbol = "figure.walk", colorHex = 0x30B0C7, heatTo = 62, coolTo = 83, subtitle = "3 Sensors"),
            ActivityProfile(name = "Home", symbol = "house.fill", colorHex = 0xFF9500, heatTo = 70, coolTo = 75, subtitle = "Thermostat"),
            ActivityProfile(name = "Sleep", symbol = "bed.double.fill", colorHex = 0xAF52DE, heatTo = 62, coolTo = 78, subtitle = "3 Sensors"),
            ActivityProfile(name = "Workout", symbol = "dumbbell.fill", colorHex = 0xFF3B30, heatTo = 62, coolTo = 78, subtitle = "3 Sensors"),
        )

        fun newBlank(): ActivityProfile =
            ActivityProfile(name = "", symbol = "house.fill", colorHex = 0xFF3B30, heatTo = 68, coolTo = 76, subtitle = "3 Sensors")
    }
}

data class TimelinePeriod(
    val id: String = newId(),
    var name: String,
    var symbol: String,
    var colorHex: Long,
    var heatTo: Int,
    var coolTo: Int,
    var startText: String,
) {
    constructor(from: ScheduleEvent) : this(
        id = from.id,
        name = from.name,
        symbol = from.symbol,
        colorHex = from.colorHex,
        heatTo = from.heatTo,
        coolTo = from.coolTo,
        startText = from.timeText,
    )
}

/** Minutes since midnight for an event start (0..<1440). */
data class ScheduleEvent(
    val id: String = newId(),
    var name: String,
    var symbol: String,
    var colorHex: Long,
    var heatTo: Int,
    var coolTo: Int,
    /** Minutes since midnight. */
    var startMinutes: Int,
) {
    val timeText: String get() = formatMinutes(startMinutes)
    val rangeText: String get() = "$heatTo · $coolTo"

    companion object {
        fun samples(profiles: List<ActivityProfile> = ActivityProfile.samples()): List<ScheduleEvent> {
            // Away, Home, Sleep, Workout — mirror Swift sample order.
            val p = profiles
            return listOf(
                ScheduleEvent(from = p[1], startMinutes = 6 * 60),
                ScheduleEvent(from = p[0], startMinutes = 8 * 60),
                ScheduleEvent(from = p[1], startMinutes = 17 * 60),
                ScheduleEvent(from = p[2], startMinutes = 22 * 60),
            )
        }
    }

    constructor(from: ActivityProfile, startMinutes: Int) : this(
        name = from.name,
        symbol = from.symbol,
        colorHex = from.colorHex,
        heatTo = from.heatTo,
        coolTo = from.coolTo,
        startMinutes = startMinutes,
    )
}

data class ScheduleDayGroup(
    val id: String = newId(),
    var days: Set<Int>,
    var events: List<ScheduleEvent>,
) {
    val dayNumbers: List<Int> get() = days.sorted()
}

data class SchedulePreset(
    val id: String = newId(),
    var name: String,
    var groups: List<ScheduleDayGroup> = listOf(
        ScheduleDayGroup(days = (0..6).toSet(), events = ScheduleEvent.samples()),
    ),
) {
    companion object {
        fun samples(): List<SchedulePreset> = listOf(
            SchedulePreset(name = "Comfort"),
            SchedulePreset(name = "Eco"),
        )
    }
}

data class ProgramEvent(
    val id: String = newId(),
    var startMinutes: Int,
    var heatTo: Int,
    var coolTo: Int,
) {
    val timeText: String get() = formatMinutes(startMinutes)
}

data class ProgramDayGroup(
    val id: String = newId(),
    var days: Set<Int>,
    var events: List<ProgramEvent>,
) {
    val dayNumbers: List<Int> get() = days.sorted()
}

data class ScheduleProgram(
    val id: String = newId(),
    var name: String,
    var groups: List<ProgramDayGroup>,
) {
    companion object {
        fun sampleEvents(): List<ProgramEvent> = listOf(
            ProgramEvent(startMinutes = 6 * 60, heatTo = 70, coolTo = 75),
            ProgramEvent(startMinutes = 8 * 60, heatTo = 62, coolTo = 80),
            ProgramEvent(startMinutes = 17 * 60, heatTo = 70, coolTo = 74),
            ProgramEvent(startMinutes = 22 * 60, heatTo = 62, coolTo = 72),
        )

        fun makeSample(name: String): ScheduleProgram = ScheduleProgram(
            name = name,
            groups = listOf(ProgramDayGroup(days = (0..6).toSet(), events = sampleEvents())),
        )

        fun samples(kind: ScheduleKind): List<ScheduleProgram> = when (kind) {
            ScheduleKind.Heat -> listOf(makeSample("Heat"), makeSample("Heat Custom 1"))
            ScheduleKind.Cool -> listOf(makeSample("Cool"), makeSample("Cool Custom 1"))
            ScheduleKind.Auto -> listOf(makeSample("Auto"), makeSample("Auto Custom 1"))
        }
    }
}

data class ServiceReminder(
    val id: String = newId(),
    var name: String,
    var type: String,
    var basedOn: ReminderBasis,
    var durationText: String,
    /** Epoch millis for next service. */
    var nextServiceEpochMs: Long,
    var lastCompletedEpochMs: Long? = null,
    var spec: String,
    var lifeRemaining: Double,
    var hasContractor: Boolean = false,
) {
    val isCritical: Boolean get() = lifeRemaining < CRITICAL_THRESHOLD

    companion object {
        const val CRITICAL_THRESHOLD = 0.25

        fun samples(nowMs: Long = platformNowMillis()): List<ServiceReminder> {
            val dayMs = 24L * 60 * 60 * 1000
            return listOf(
                ServiceReminder(
                    name = "Upstairs Air Filter",
                    type = "Air Filter",
                    basedOn = ReminderBasis.Runtime,
                    durationText = "300 Hours",
                    nextServiceEpochMs = nowMs + 60 * dayMs,
                    lastCompletedEpochMs = nowMs - 305 * dayMs,
                    spec = "16\" x 25\" x 2\" - MERV8",
                    lifeRemaining = 0.8,
                ),
                ServiceReminder(
                    name = "Downstairs Air Filter",
                    type = "Air Filter",
                    basedOn = ReminderBasis.Runtime,
                    durationText = "300 Hours",
                    nextServiceEpochMs = nowMs + 6 * dayMs,
                    lastCompletedEpochMs = nowMs - 305 * dayMs,
                    spec = "16\" x 25\" x 2\" - MERV8",
                    lifeRemaining = 0.15,
                    hasContractor = true,
                ),
            )
        }
    }
}

data class Contractor(
    var company: String = "",
    var address: String = "",
    var phone: String = "",
    var city: String = "",
    var state: String = "",
    var country: String = "",
) {
    val phoneDigits: String get() = phone.filter { it.isDigit() }

    companion object {
        fun sample(): Contractor = Contractor(
            company = "123 HVAC Contracting Company",
            address = "ABC Ave",
            phone = "555555",
            city = "Villagetownsburg",
            state = "Missouri",
            country = "United States",
        )
    }
}

data class ThermostatSettings(
    var continuousBacklight: Boolean = true,
    var displayHumidity: Boolean = true,
    var displayTime: Boolean = true,
    var units: TemperatureUnit = TemperatureUnit.Fahrenheit,
    var lockThermostat: Boolean = false,
    var coolingMin: Int = 55,
    var heatingMax: Int = 99,
    var humidification: Boolean = true,
    var humidifyTo: Int = 40,
    var dehumidification: Boolean = true,
    var dehumidifyTo: Int = 40,
    var coolingBoost: String = "Comfort",
    var heatingBoost: String = "Comfort",
    var auxBoost: String = "Comfort",
    var temperatureOffset: Int = 0,
    var humidityOffset: Int = 0,
    var acProtection: Boolean = true,
    var name: String = "",
    var locationAddress: String = "",
    var locationUnit: String = "",
    var locationCity: String = "",
    var locationState: String = "",
    var locationZip: String = "",
    var locationCountry: String = "United States",
)

fun formatMinutes(minutes: Int): String {
    val m = ((minutes % 1440) + 1440) % 1440
    val h24 = m / 60
    val min = m % 60
    val am = h24 < 12
    val h12 = when (val h = h24 % 12) {
        0 -> 12
        else -> h
    }
    val mm = min.toString().padStart(2, '0')
    return "$h12:$mm${if (am) "AM" else "PM"}"
}
