package com.sensi.petticoat.model

/**
 * Explicit construction API for Swift. Keeping construction here avoids relying on
 * Kotlin default-argument and collection bridging details in generated framework APIs.
 */
object SharedModelFactory {
    fun profile(
        id: String,
        name: String,
        symbol: String,
        colorHex: Long,
        heatTo: Int,
        coolTo: Int,
        subtitle: String,
    ) = ActivityProfile(id, name, symbol, colorHex, heatTo, coolTo, subtitle)

    fun scheduleEvent(
        id: String,
        name: String,
        symbol: String,
        colorHex: Long,
        heatTo: Int,
        coolTo: Int,
        startMinutes: Int,
    ) = ScheduleEvent(id, name, symbol, colorHex, heatTo, coolTo, startMinutes)

    fun scheduleGroup(
        id: String,
        dayNumbers: List<Int>,
        events: List<ScheduleEvent>,
    ) = ScheduleDayGroup(id, dayNumbers.toSet(), events)

    fun schedule(
        id: String,
        name: String,
        groups: List<ScheduleDayGroup>,
    ) = SchedulePreset(id, name, groups)

    fun programEvent(
        id: String,
        startMinutes: Int,
        heatTo: Int,
        coolTo: Int,
    ) = ProgramEvent(id, startMinutes, heatTo, coolTo)

    fun programGroup(
        id: String,
        dayNumbers: List<Int>,
        events: List<ProgramEvent>,
    ) = ProgramDayGroup(id, dayNumbers.toSet(), events)

    fun program(
        id: String,
        name: String,
        groups: List<ProgramDayGroup>,
    ) = ScheduleProgram(id, name, groups)

    fun reminder(
        id: String,
        name: String,
        type: String,
        basedOn: String,
        durationText: String,
        nextServiceEpochMs: Long,
        lastCompletedEpochMs: Long,
        spec: String,
        lifeRemaining: Double,
        hasContractor: Boolean,
    ) = ServiceReminder(
        id = id,
        name = name,
        type = type,
        basedOn = ReminderBasis.entries.firstOrNull { it.wireValue == basedOn }
            ?: ReminderBasis.Runtime,
        durationText = durationText,
        nextServiceEpochMs = nextServiceEpochMs,
        lastCompletedEpochMs = lastCompletedEpochMs.takeIf { it >= 0 },
        spec = spec,
        lifeRemaining = lifeRemaining,
        hasContractor = hasContractor,
    )

    fun home(
        id: String,
        name: String,
        homeSize: String,
        hvacSystemType: String,
    ) = Home(
        id = id,
        name = name,
        homeSize = HomeSize.entries.firstOrNull { it.wireValue == homeSize } ?: HomeSize.Medium,
        hvacSystemType = HVACSystemType.entries.firstOrNull { it.wireValue == hvacSystemType }
            ?: HVACSystemType.GasFurnace,
    )

    fun contractor(
        company: String,
        address: String,
        phone: String,
        city: String,
        state: String,
        country: String,
    ) = Contractor(company, address, phone, city, state, country)

    @Suppress("LongParameterList")
    fun thermostatSettings(
        continuousBacklight: Boolean,
        displayHumidity: Boolean,
        displayTime: Boolean,
        units: String,
        lockThermostat: Boolean,
        coolingMin: Int,
        heatingMax: Int,
        humidification: Boolean,
        humidifyTo: Int,
        dehumidification: Boolean,
        dehumidifyTo: Int,
        coolingBoost: String,
        heatingBoost: String,
        auxBoost: String,
        temperatureOffset: Int,
        humidityOffset: Int,
        acProtection: Boolean,
        name: String,
        locationAddress: String,
        locationUnit: String,
        locationCity: String,
        locationState: String,
        locationZip: String,
        locationCountry: String,
    ) = ThermostatSettings(
        continuousBacklight = continuousBacklight,
        displayHumidity = displayHumidity,
        displayTime = displayTime,
        units = TemperatureUnit.entries.firstOrNull { it.wireValue == units }
            ?: TemperatureUnit.Fahrenheit,
        lockThermostat = lockThermostat,
        coolingMin = coolingMin,
        heatingMax = heatingMax,
        humidification = humidification,
        humidifyTo = humidifyTo,
        dehumidification = dehumidification,
        dehumidifyTo = dehumidifyTo,
        coolingBoost = coolingBoost,
        heatingBoost = heatingBoost,
        auxBoost = auxBoost,
        temperatureOffset = temperatureOffset,
        humidityOffset = humidityOffset,
        acProtection = acProtection,
        name = name,
        locationAddress = locationAddress,
        locationUnit = locationUnit,
        locationCity = locationCity,
        locationState = locationState,
        locationZip = locationZip,
        locationCountry = locationCountry,
    )
}
