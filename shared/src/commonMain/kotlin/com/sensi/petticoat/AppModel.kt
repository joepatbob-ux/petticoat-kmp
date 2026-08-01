package com.sensi.petticoat

import com.sensi.petticoat.math.TimelineMath
import com.sensi.petticoat.model.ActivityProfile
import com.sensi.petticoat.model.AppAppearance
import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.Contractor
import com.sensi.petticoat.model.DashboardSection
import com.sensi.petticoat.model.Device
import com.sensi.petticoat.model.DeviceTab
import com.sensi.petticoat.model.FanMode
import com.sensi.petticoat.model.HoldDuration
import com.sensi.petticoat.model.Home
import com.sensi.petticoat.model.ScheduleKind
import com.sensi.petticoat.model.SchedulePreset
import com.sensi.petticoat.model.ScheduleProgram
import com.sensi.petticoat.model.ServiceReminder
import com.sensi.petticoat.model.SetpointBound
import com.sensi.petticoat.model.SetpointConfig
import com.sensi.petticoat.model.SpotlightItem
import com.sensi.petticoat.model.StepperStyle
import com.sensi.petticoat.model.SystemMode
import com.sensi.petticoat.model.ThermostatSettings
import com.sensi.petticoat.model.TimelinePeriod
import com.sensi.petticoat.model.formatMinutes
import com.sensi.petticoat.model.newId
import com.sensi.petticoat.model.platformNowMillis
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class TimelineEntry(val minutes: Int, val period: TimelinePeriod)

enum class Route { Splash, Login, Main }

/**
 * Snapshot of all app state. Views collect [AppModel.state]; mutations go through
 * methods on [AppModel]. Mirrors the Swift `@Observable AppModel`.
 */
data class AppState(
    val route: Route = Route.Splash,
    val showAccount: Boolean = false,
    val showAddDevice: Boolean = false,
    val showHelp: Boolean = false,
    val selectedTab: DeviceTab = DeviceTab.Control,
    val sidebarVisible: Boolean = true,
    val addingReminder: Boolean = false,
    val devices: List<Device> = listOf(Device.sample(), Device.sampleUpstairs()),
    val selectedDeviceId: String? = null,
    val spotlights: List<SpotlightItem> = SpotlightItem.samples(),
    val hiddenSpotlights: Set<String> = emptySet(),
    val dashboardSectionOrder: List<DashboardSection> =
        listOf(DashboardSection.Thermostats, DashboardSection.Spotlight),
    val showSensorsOnDashboard: Boolean = true,
    val appearance: AppAppearance = AppAppearance.System,
    val showWeatherLocation: Boolean = true,
    val stepperStyle: StepperStyle = StepperStyle.PlusMinus,
    val homes: List<Home> = listOf(Home(name = "Home")),
    val controlMode: ControlMode = ControlMode.Schedule,
    val holdDuration: HoldDuration = HoldDuration.OneHour,
    val holdEndsAtEpochMs: Long? = null,
    val activeProfile: ActivityProfile = ActivityProfile.samples()[1],
    val activityProfiles: List<ActivityProfile> = ActivityProfile.samples(),
    val schedules: List<SchedulePreset> = SchedulePreset.samples(),
    val selectedScheduleId: String? = null,
    val programs: Map<ScheduleKind, List<ScheduleProgram>> = mapOf(
        ScheduleKind.Heat to ScheduleProgram.samples(ScheduleKind.Heat),
        ScheduleKind.Cool to ScheduleProgram.samples(ScheduleKind.Cool),
        ScheduleKind.Auto to ScheduleProgram.samples(ScheduleKind.Auto),
    ),
    val selectedProgramId: Map<ScheduleKind, String> = emptyMap(),
    val serviceReminders: List<ServiceReminder> = ServiceReminder.samples(),
    val contractor: Contractor = Contractor.sample(),
    val thermostatSettings: ThermostatSettings = ThermostatSettings(),
    val todaysTimeline: List<TimelineEntry> = emptyList(),
) {
    val device: Device
        get() = devices.firstOrNull { it.id == selectedDeviceId }
            ?: devices.firstOrNull()
            ?: Device.sample()

    val visibleSpotlights: List<SpotlightItem>
        get() = spotlights.filter { it.id !in hiddenSpotlights }

    val criticalReminderCount: Int get() = serviceReminders.count { it.isCritical }

    val activeSchedule: SchedulePreset?
        get() = schedules.firstOrNull { it.id == selectedScheduleId } ?: schedules.firstOrNull()

    private val activeKind: ScheduleKind?
        get() = when (device.systemMode) {
            SystemMode.Heat, SystemMode.AuxHeat -> ScheduleKind.Heat
            SystemMode.Cool -> ScheduleKind.Cool
            SystemMode.Auto -> ScheduleKind.Auto
            SystemMode.Off -> null
        }

    val activeProgram: ScheduleProgram?
        get() {
            val kind = activeKind ?: return null
            val list = programs[kind].orEmpty()
            if (list.isEmpty()) return null
            return list.firstOrNull { it.id == selectedProgramId[kind] } ?: list.first()
        }

    val scheduleName: String
        get() {
            val name = if (device.usePresets) activeSchedule?.name else activeProgram?.name
            return name ?: device.scheduleName
        }

    fun currentPeriod(nowMinutes: Int = platformNowMinutes()): TimelinePeriod? {
        val idx = TimelineMath.currentIndex(todaysTimeline.map { it.minutes }, nowMinutes)
            ?: return null
        return todaysTimeline[idx].period
    }

    fun upcomingPeriods(nowMinutes: Int = platformNowMinutes()): List<TimelinePeriod> {
        val t = todaysTimeline
        return TimelineMath.upcomingIndices(t.map { it.minutes }, nowMinutes).map { t[it].period }
    }

    val holdUntilText: String
        get() {
            val end = holdEndsAtEpochMs ?: return "you resume it"
            val mins = ((end / 60_000) % (24 * 60)).toInt()
            val time = formatMinutes(mins)
            return if (device.geofenceEnabled) "$time or Away" else time
        }
}

/**
 * Single source of truth for Petticoat. Collect [state] from Compose / SwiftUI
 * bridges; call mutation methods to update.
 */
class AppModel(
    private val clockMinutes: () -> Int = { platformNowMinutes() },
    private val weekdayIndex: () -> Int = { platformWeekdayIndex() },
) {
    private val _state = MutableStateFlow(seedState())
    val state: StateFlow<AppState> = _state.asStateFlow()

    val snapshot: AppState get() = _state.value

    private fun seedState(): AppState {
        var s = AppState()
        val defaultHomeId = s.homes.first().id
        s = s.copy(devices = s.devices.map { it.copy(homeId = defaultHomeId) })
        return recompute(s)
    }

    private fun update(transform: (AppState) -> AppState) {
        _state.update { recompute(transform(it)) }
    }

    private fun recompute(s: AppState): AppState =
        s.copy(todaysTimeline = buildTimeline(s))

    private fun buildTimeline(s: AppState): List<TimelineEntry> {
        val today = weekdayIndex()
        return if (s.device.usePresets) {
            val schedule = s.activeSchedule ?: return emptyList()
            if (schedule.groups.isEmpty()) return emptyList()
            val group = schedule.groups.firstOrNull { today in it.days } ?: schedule.groups[0]
            group.events.sortedBy { it.startMinutes }
                .map { TimelineEntry(it.startMinutes, TimelinePeriod(it)) }
        } else {
            val program = s.activeProgram ?: return emptyList()
            if (program.groups.isEmpty()) return emptyList()
            val group = program.groups.firstOrNull { today in it.days } ?: program.groups[0]
            group.events.sortedBy { it.startMinutes }
                .map { e ->
                    TimelineEntry(
                        e.startMinutes,
                        TimelinePeriod(
                            id = e.id,
                            name = e.timeText,
                            symbol = "",
                            colorHex = 0,
                            heatTo = e.heatTo,
                            coolTo = e.coolTo,
                            startText = e.timeText,
                        ),
                    )
                }
        }
    }

    fun finishSplash() = update { it.copy(route = Route.Login) }
    fun signIn() = update { it.copy(route = Route.Main) }
    fun signOut() = update {
        it.copy(
            route = Route.Login,
            showAccount = false,
            showAddDevice = false,
            showHelp = false,
        )
    }

    fun setShowAccount(v: Boolean) = update { it.copy(showAccount = v) }
    fun setShowAddDevice(v: Boolean) = update { it.copy(showAddDevice = v) }
    fun setShowHelp(v: Boolean) = update { it.copy(showHelp = v) }
    fun setSelectedTab(tab: DeviceTab) = update { it.copy(selectedTab = tab) }
    fun setAddingReminder(v: Boolean) = update { it.copy(addingReminder = v) }

    fun selectDevice(id: String?) = update { it.copy(selectedDeviceId = id) }

    fun clearSelectedDevice() = update { it.copy(selectedDeviceId = null) }

    fun markSelectedDeviceOnline() = update { s ->
        val id = s.device.id
        s.copy(devices = s.devices.map {
            if (it.id == id) it.copy(isOffline = false, offlineSince = null) else it
        })
    }

    fun moveDevices(fromIndex: Int, toIndex: Int) = update { s ->
        s.copy(devices = s.devices.toMutableList().also { move(it, fromIndex, toIndex) })
    }

    fun adjustKeep(bound: SetpointBound, delta: Int, deviceId: String? = null) = update { s ->
        val id = deviceId ?: s.device.id
        val devices = s.devices.toMutableList()
        val i = devices.indexOfFirst { it.id == id }
        if (i < 0) return@update s
        val d = devices[i].copy()
        val lo = SetpointConfig.MIN_TEMP
        val hi = SetpointConfig.MAX_TEMP
        val gap = SetpointConfig.DEADBAND
        if (d.systemMode.isRangeSetpoint) {
            when (bound) {
                SetpointBound.Low -> {
                    val v = (d.keepMin + delta).coerceIn(lo, hi - gap)
                    d.keepMin = v
                    if (d.keepMax < v + gap) d.keepMax = v + gap
                }
                SetpointBound.High -> {
                    val v = (d.keepMax + delta).coerceIn(lo + gap, hi)
                    d.keepMax = v
                    if (d.keepMin > v - gap) d.keepMin = v - gap
                }
            }
        } else if (d.systemMode == SystemMode.Cool) {
            d.keepMax = (d.keepMax + delta).coerceIn(lo + gap, hi)
            d.keepMin = minOf(d.keepMin, d.keepMax - gap)
        } else {
            d.keepMin = (d.keepMin + delta).coerceIn(lo, hi - gap)
            d.keepMax = maxOf(d.keepMax, d.keepMin + gap)
        }
        devices[i] = d
        var next = s.copy(devices = devices)
        if (s.controlMode == ControlMode.Schedule) {
            next = next.copy(
                holdEndsAtEpochMs = holdEndEpoch(s.holdDuration),
                controlMode = ControlMode.Hold,
            )
        }
        next
    }

    fun nudgeSetpoint(delta: Int) {
        when (snapshot.device.systemMode) {
            SystemMode.Heat, SystemMode.AuxHeat -> adjustKeep(SetpointBound.Low, delta)
            SystemMode.Cool -> adjustKeep(SetpointBound.High, delta)
            SystemMode.Auto, SystemMode.Off -> {
                adjustKeep(SetpointBound.Low, delta)
                adjustKeep(SetpointBound.High, delta)
            }
        }
    }

    fun setSystemMode(mode: SystemMode, deviceId: String? = null) = update { s ->
        val id = deviceId ?: s.device.id
        s.copy(devices = s.devices.map {
            if (it.id == id) it.copy(systemMode = mode) else it
        })
    }

    fun setFanMode(mode: FanMode, deviceId: String? = null) = update { s ->
        val id = deviceId ?: s.device.id
        s.copy(devices = s.devices.map {
            if (it.id == id) it.copy(fanMode = mode) else it
        })
    }

    fun toggleSensor(sensorId: String, deviceId: String) = update { s ->
        s.copy(devices = s.devices.map { d ->
            if (d.id != deviceId) return@map d
            val sensors = d.sensors.toMutableList()
            val si = sensors.indexOfFirst { it.id == sensorId }
            if (si < 0) return@map d
            if (sensors[si].participating && sensors.count { it.participating } <= 1) return@map d
            sensors[si] = sensors[si].copy(participating = !sensors[si].participating)
            d.copy(sensors = sensors)
        })
    }

    fun renameSensor(sensorId: String, name: String, deviceId: String) = update { s ->
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return@update s
        s.copy(devices = s.devices.map { d ->
            if (d.id != deviceId) return@map d
            d.copy(sensors = d.sensors.map {
                if (it.id == sensorId) it.copy(name = trimmed) else it
            })
        })
    }

    fun setScheduleEnabled(enabled: Boolean) = update {
        it.copy(controlMode = if (enabled) ControlMode.Schedule else ControlMode.Standard)
    }

    fun activateProfile(profile: ActivityProfile) = update {
        it.copy(activeProfile = profile, controlMode = ControlMode.Activity)
    }

    fun activateProfileNamed(name: String) {
        snapshot.activityProfiles.firstOrNull { it.name == name }?.let { activateProfile(it) }
    }

    fun saveProfile(updated: ActivityProfile) = update { s ->
        val list = s.activityProfiles.toMutableList()
        val i = list.indexOfFirst { it.id == updated.id }
        if (i >= 0) list[i] = updated else list.add(updated)
        s.copy(
            activityProfiles = list,
            activeProfile = if (s.activeProfile.id == updated.id) updated else s.activeProfile,
        )
    }

    fun duplicateProfile(profile: ActivityProfile) = update { s ->
        val i = s.activityProfiles.indexOfFirst { it.id == profile.id }
        if (i < 0) return@update s
        val copy = profile.copy(id = newId(), name = profile.name + " Copy")
        s.copy(activityProfiles = s.activityProfiles.toMutableList().also { it.add(i + 1, copy) })
    }

    fun deleteProfile(profileId: String) = update {
        it.copy(activityProfiles = it.activityProfiles.filterNot { p -> p.id == profileId })
    }

    fun setVacation(on: Boolean, profile: ActivityProfile? = null) = update { s ->
        var devices = s.devices
        if (on && profile != null) {
            val id = s.device.id
            devices = devices.map {
                if (it.id == id) it.copy(keepMin = profile.heatTo, keepMax = profile.coolTo) else it
            }
        }
        s.copy(
            devices = devices,
            controlMode = if (on) ControlMode.Vacation else ControlMode.Schedule,
        )
    }

    fun resumeSchedule() = update { s ->
        syncScheduleSetpoints(s.copy(holdEndsAtEpochMs = null, controlMode = ControlMode.Schedule))
    }

    fun selectSchedule(id: String) = update { s ->
        syncScheduleSetpoints(s.copy(selectedScheduleId = id))
    }

    fun saveSchedule(updated: SchedulePreset) = update { s ->
        val list = s.schedules.toMutableList()
        val i = list.indexOfFirst { it.id == updated.id }
        var selected = s.selectedScheduleId
        if (i >= 0) list[i] = updated else {
            list.add(updated)
            selected = updated.id
        }
        var next = s.copy(schedules = list, selectedScheduleId = selected)
        if (next.activeSchedule?.id == updated.id) next = syncScheduleSetpoints(next)
        next
    }

    fun duplicateSchedule(preset: SchedulePreset) = update { s ->
        val i = s.schedules.indexOfFirst { it.id == preset.id }
        if (i < 0) return@update s
        val base = preset.name + " (Copy)"
        val taken = s.schedules.map { it.name }.toSet()
        var candidate = base
        var n = 2
        while (candidate in taken) {
            candidate = "$base $n"
            n++
        }
        val copy = preset.copy(id = newId(), name = candidate)
        s.copy(schedules = s.schedules.toMutableList().also { it.add(i + 1, copy) })
    }

    fun deleteSchedule(id: String) = update { s ->
        val list = s.schedules.filterNot { it.id == id }
        var selected = s.selectedScheduleId
        if (selected == id) selected = list.firstOrNull()?.id
        syncScheduleSetpoints(s.copy(schedules = list, selectedScheduleId = selected))
    }

    fun selectProgram(id: String, kind: ScheduleKind) = update {
        it.copy(selectedProgramId = it.selectedProgramId + (kind to id))
    }

    fun saveProgram(program: ScheduleProgram, kind: ScheduleKind) = update { s ->
        val list = (s.programs[kind].orEmpty()).toMutableList()
        val i = list.indexOfFirst { it.id == program.id }
        val selected = s.selectedProgramId.toMutableMap()
        if (i >= 0) list[i] = program else {
            list.add(program)
            selected[kind] = program.id
        }
        s.copy(programs = s.programs + (kind to list), selectedProgramId = selected)
    }

    fun deleteProgram(id: String, kind: ScheduleKind) = update { s ->
        val list = s.programs[kind].orEmpty().filterNot { it.id == id }
        val selected = s.selectedProgramId.toMutableMap()
        if (selected[kind] == id) {
            val first = list.firstOrNull()?.id
            if (first == null) selected.remove(kind) else selected[kind] = first
        }
        s.copy(programs = s.programs + (kind to list), selectedProgramId = selected)
    }

    fun saveReminder(reminder: ServiceReminder) = update { s ->
        val list = s.serviceReminders.toMutableList()
        val i = list.indexOfFirst { it.id == reminder.id }
        if (i >= 0) list[i] = reminder else list.add(reminder)
        s.copy(serviceReminders = list)
    }

    fun deleteReminder(id: String) = update {
        it.copy(serviceReminders = it.serviceReminders.filterNot { r -> r.id == id })
    }

    fun completeReminder(id: String) = update { s ->
        s.copy(serviceReminders = s.serviceReminders.map {
            if (it.id == id) it.copy(lifeRemaining = 1.0) else it
        })
    }

    fun dismissSpotlight(itemId: String) = update {
        it.copy(spotlights = it.spotlights.filterNot { s -> s.id == itemId })
    }

    fun setSpotlightHidden(itemId: String, hidden: Boolean) = update { s ->
        s.copy(
            hiddenSpotlights = if (hidden) s.hiddenSpotlights + itemId
            else s.hiddenSpotlights - itemId,
        )
    }

    fun assignDevice(deviceId: String, homeId: String?) = update { s ->
        s.copy(devices = s.devices.map {
            if (it.id == deviceId) it.copy(homeId = homeId) else it
        })
    }

    private fun syncScheduleSetpoints(s: AppState): AppState {
        if (s.controlMode != ControlMode.Schedule) return s
        val p = s.currentPeriod(clockMinutes()) ?: return s
        val id = s.device.id
        return s.copy(devices = s.devices.map {
            if (it.id == id) it.copy(keepMin = p.heatTo, keepMax = p.coolTo) else it
        })
    }

    private fun holdEndEpoch(duration: HoldDuration): Long? {
        val hours = duration.hours ?: return null
        return platformNowMillis() + hours * 3_600_000L
    }
}

private fun <T> move(list: MutableList<T>, from: Int, to: Int) {
    if (from !in list.indices) return
    val item = list.removeAt(from)
    list.add(to.coerceIn(0, list.size), item)
}

/** Minutes since midnight (local). */
expect fun platformNowMinutes(): Int

/** Weekday index 0 = Monday … 6 = Sunday. */
expect fun platformWeekdayIndex(): Int
