package com.sensi.petticoat

import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.HVACActivity
import com.sensi.petticoat.model.HoldDuration
import com.sensi.petticoat.model.Home
import com.sensi.petticoat.model.DistanceUnit
import com.sensi.petticoat.model.ScheduleKind
import com.sensi.petticoat.model.ScheduleProgram
import com.sensi.petticoat.model.ServiceReminder
import com.sensi.petticoat.model.SetpointBound
import com.sensi.petticoat.model.SetpointConfig
import com.sensi.petticoat.model.SystemMode
import com.sensi.petticoat.model.VacationTrip
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AppModelTest {
    private fun model(now: Long = 1_700_000_000_000L) =
        AppModel(clockMinutes = { 600 }, weekdayIndex = { 0 }, nowMillis = { now })

    @Test
    fun signInMovesToMain() {
        val model = AppModel(clockMinutes = { 600 }, weekdayIndex = { 0 })
        model.finishSplash()
        model.signIn()
        assertEquals(Route.Main, model.snapshot.route)
    }

    @Test
    fun adjustKeepCreatesHoldFromSchedule() {
        val model = AppModel(clockMinutes = { 600 }, weekdayIndex = { 0 })
        assertEquals(ControlMode.Schedule, model.snapshot.controlMode)
        val before = model.snapshot.device.keepMax
        model.adjustKeep(SetpointBound.High, 1)
        assertEquals(ControlMode.Hold, model.snapshot.controlMode)
        assertEquals(before + 1, model.snapshot.device.keepMax)
    }

    @Test
    fun deviceActivityDerivedFromModeAndTemp() {
        val model = AppModel(clockMinutes = { 600 }, weekdayIndex = { 0 })
        model.setSystemMode(SystemMode.Cool)
        // Sample sensors average ~71; keepMax starts at 73 → idle
        assertEquals(HVACActivity.Idle, model.snapshot.device.activity)
        model.adjustKeep(SetpointBound.High, -10) // cool target below temp → cooling
        assertEquals(HVACActivity.Cooling, model.snapshot.device.activity)
    }

    @Test
    fun timelineBuiltFromSchedule() {
        val model = AppModel(clockMinutes = { 600 }, weekdayIndex = { 0 })
        assertTrue(model.snapshot.todaysTimeline.isNotEmpty())
        assertEquals(4, model.snapshot.todaysTimeline.size)
    }

    @Test
    fun setpointBoundsClampAndKeepDeadband() {
        val model = model()
        repeat(100) { model.adjustKeep(SetpointBound.Low, 1) }
        assertEquals(SetpointConfig.MAX_TEMP - SetpointConfig.DEADBAND, model.snapshot.device.keepMin)
        assertEquals(SetpointConfig.MAX_TEMP, model.snapshot.device.keepMax)

        model.setControlMode(ControlMode.Standard)
        repeat(100) { model.adjustKeep(SetpointBound.High, -1) }
        assertEquals(SetpointConfig.MIN_TEMP, model.snapshot.device.keepMin)
        assertEquals(SetpointConfig.MIN_TEMP + SetpointConfig.DEADBAND, model.snapshot.device.keepMax)
    }

    @Test
    fun adjustingOutsideScheduleDoesNotCreateHold() {
        val model = model()
        model.setControlMode(ControlMode.Standard)
        model.adjustKeep(SetpointBound.High, 1)
        assertEquals(ControlMode.Standard, model.snapshot.controlMode)
        assertNull(model.snapshot.holdEndsAtEpochMs)
    }

    @Test
    fun holdDurationReanchorsOnlyWhileHolding() {
        val model = model()
        model.setHoldDuration(HoldDuration.OneHour)
        model.adjustKeep(SetpointBound.High, 1)
        val oneHour = model.snapshot.holdEndsAtEpochMs
        model.setHoldDuration(HoldDuration.TwoHours)
        val twoHours = model.snapshot.holdEndsAtEpochMs
        assertNotNull(oneHour)
        assertEquals(oneHour + 3_600_000L, twoHours)

        model.resumeSchedule()
        model.setControlMode(ControlMode.Standard)
        model.setHoldDuration(HoldDuration.ThreeHours)
        assertNull(model.snapshot.holdEndsAtEpochMs)
    }

    @Test
    fun indefiniteHoldUsesResumePhrase() {
        val model = model()
        model.setHoldDuration(HoldDuration.Indefinite)
        model.adjustKeep(SetpointBound.High, 1)
        assertEquals("you resume it", model.snapshot.holdUntilText)
    }

    @Test
    fun scheduleToggleDrivesControlMode() {
        val model = model()
        model.setScheduleEnabled(false)
        assertEquals(ControlMode.Standard, model.snapshot.controlMode)
        model.setScheduleEnabled(true)
        assertEquals(ControlMode.Schedule, model.snapshot.controlMode)
    }

    @Test
    fun profileAndVacationTransitions() {
        val model = model()
        val away = model.snapshot.activityProfiles.first()
        model.activateProfile(away)
        assertEquals(ControlMode.Activity, model.snapshot.controlMode)
        assertEquals(away.id, model.snapshot.activeProfile.id)

        model.setVacation(true, away)
        assertEquals(ControlMode.Vacation, model.snapshot.controlMode)
        assertEquals(away.heatTo, model.snapshot.device.keepMin)
        assertEquals(away.coolTo, model.snapshot.device.keepMax)
        model.resumeSchedule()
        assertEquals(ControlMode.Schedule, model.snapshot.controlMode)
    }

    @Test
    fun profileCrudMaintainsIdentity() {
        val model = model()
        val original = model.snapshot.activityProfiles.first()
        model.saveProfile(original.copy(name = "Renamed"))
        assertEquals("Renamed", model.snapshot.activityProfiles.first().name)
        model.duplicateProfile(model.snapshot.activityProfiles.first())
        assertEquals("Renamed Copy", model.snapshot.activityProfiles[1].name)
        assertNotEquals(model.snapshot.activityProfiles[0].id, model.snapshot.activityProfiles[1].id)
        model.deleteProfile(original.id)
        assertFalse(model.snapshot.activityProfiles.any { it.id == original.id })
    }

    @Test
    fun reminderCrudAndCompletionStampsDates() {
        val now = 1_700_000_000_000L
        val model = model(now)
        val reminder = ServiceReminder(
            name = "Test",
            type = "Filter",
            basedOn = com.sensi.petticoat.model.ReminderBasis.Runtime,
            durationText = "300 Hours",
            nextServiceEpochMs = now,
            spec = "",
            lifeRemaining = 0.1,
        )
        model.saveReminder(reminder)
        model.completeReminder(reminder.id)
        val completed = model.snapshot.serviceReminders.first { it.id == reminder.id }
        assertEquals(1.0, completed.lifeRemaining)
        assertEquals(now, completed.lastCompletedEpochMs)
        assertTrue(completed.nextServiceEpochMs > now)
        model.deleteReminder(reminder.id)
        assertFalse(model.snapshot.serviceReminders.any { it.id == reminder.id })
    }

    @Test
    fun scheduleCrudSelectsAndReselects() {
        val model = model()
        val second = model.snapshot.schedules[1]
        model.selectSchedule(second.id)
        assertEquals(second.id, model.snapshot.activeSchedule?.id)
        val copySource = model.snapshot.schedules.first()
        model.duplicateSchedule(copySource)
        assertTrue(model.snapshot.schedules[1].name.startsWith(copySource.name))
        model.deleteSchedule(second.id)
        assertNotEquals(second.id, model.snapshot.selectedScheduleId)
    }

    @Test
    fun programCrudIsIsolatedByKind() {
        val model = model()
        val beforeCool = model.programsFor(ScheduleKind.Cool).size
        val program = ScheduleProgram.makeSample("Custom Heat")
        model.saveProgram(program, ScheduleKind.Heat)
        assertEquals(program.id, model.activeProgramId(ScheduleKind.Heat))
        model.duplicateProgram(program, ScheduleKind.Heat)
        assertTrue(model.programsFor(ScheduleKind.Heat).any { it.name == "Custom Heat Copy" })
        assertEquals(beforeCool, model.programsFor(ScheduleKind.Cool).size)
        model.deleteProgram(program.id, ScheduleKind.Heat)
        assertFalse(model.programsFor(ScheduleKind.Heat).any { it.id == program.id })
    }

    @Test
    fun sensorsCannotDeselectLastParticipantAndCanRename() {
        val model = model()
        val deviceId = model.snapshot.device.id
        model.snapshot.device.sensors.filter { it.participating }.forEach {
            model.toggleSensor(it.id, deviceId)
        }
        assertEquals(1, model.snapshot.device.participatingCount)
        val last = model.snapshot.device.sensors.first { it.participating }
        model.toggleSensor(last.id, deviceId)
        assertEquals(1, model.snapshot.device.participatingCount)
        model.renameSensor(last.id, " Living Room ", deviceId)
        assertEquals("Living Room", model.snapshot.device.sensors.first { it.id == last.id }.name)
    }

    @Test
    fun singleModeSetpointsMoveCorrectTarget() {
        val model = model()
        model.setSystemMode(SystemMode.Heat)
        val heat = model.snapshot.device.keepMin
        model.adjustKeep(SetpointBound.High, 2)
        assertEquals(heat + 2, model.snapshot.device.keepMin)

        model.setControlMode(ControlMode.Standard)
        model.setSystemMode(SystemMode.Cool)
        val cool = model.snapshot.device.keepMax
        model.adjustKeep(SetpointBound.Low, -2)
        assertEquals(cool - 2, model.snapshot.device.keepMax)
    }

    @Test
    fun spotlightVisibilityAndOrderingMutateSharedState() {
        val model = model()
        val first = model.snapshot.spotlights.first()
        model.setSpotlightHidden(first.id, true)
        assertFalse(model.snapshot.visibleSpotlights.any { it.id == first.id })
        model.setSpotlightHidden(first.id, false)
        assertTrue(model.snapshot.visibleSpotlights.any { it.id == first.id })
        model.moveSpotlights(0, 2)
        assertEquals(first.id, model.snapshot.spotlights[2].id)
        model.dismissSpotlight(first.id)
        assertFalse(model.snapshot.spotlights.any { it.id == first.id })
    }

    @Test
    fun deviceOptionsAndOfflineRecoveryMutateSelectedDevice() {
        val model = model()
        val upstairs = model.snapshot.devices[1]
        model.selectDevice(upstairs.id)
        model.markSelectedDeviceOnline()
        model.setDeviceGeofenceEnabled(false)
        model.setDeviceUsePresets(false)
        model.setDeviceEarlyStart(false)
        assertFalse(model.snapshot.device.isOffline)
        assertNull(model.snapshot.device.offlineSince)
        assertFalse(model.snapshot.device.geofenceEnabled)
        assertFalse(model.snapshot.device.usePresets)
        assertFalse(model.snapshot.device.earlyStart)
    }

    @Test
    fun homesCrudClearsDeletedAssignments() {
        val model = model()
        val home = Home(name = "Cabin")
        model.addHome(home)
        model.assignDevice(model.snapshot.device.id, home.id)
        model.updateHome(home.copy(name = "Lake Cabin"))
        assertEquals("Lake Cabin", model.snapshot.homes.first { it.id == home.id }.name)
        model.deleteHomes(listOf(home.id))
        assertFalse(model.snapshot.homes.any { it.id == home.id })
        assertNull(model.snapshot.device.homeId)
    }

    @Test
    fun sharedPreferencesAndSettingsAreReplaceable() {
        val model = model()
        model.setShowWeatherLocation(false)
        model.setShowSensorsOnDashboard(false)
        model.setSidebarVisible(false)
        model.setThermostatSettings(
            model.snapshot.thermostatSettings.copy(displayHumidity = false),
        )
        assertFalse(model.snapshot.showWeatherLocation)
        assertFalse(model.snapshot.showSensorsOnDashboard)
        assertFalse(model.snapshot.sidebarVisible)
        assertFalse(model.snapshot.thermostatSettings.displayHumidity)
    }

    @Test
    fun syncScheduleSetpointsUsesInjectedClock() {
        val model = model()
        val period = model.snapshot.currentPeriod(600)
        assertNotNull(period)
        model.syncScheduleSetpoints()
        assertEquals(period.heatTo, model.snapshot.device.keepMin)
        assertEquals(period.coolTo, model.snapshot.device.keepMax)
    }

    @Test
    fun geofenceRadiusAndUnitPersistAndClamp() {
        val model = model()
        model.setDeviceGeofenceRadius(9)
        model.setDeviceGeofenceUnit(DistanceUnit.Kilometers)
        assertEquals(9, model.snapshot.device.geofenceRadius)
        assertEquals(DistanceUnit.Kilometers, model.snapshot.device.geofenceUnit)
        model.setDeviceGeofenceRadius(99)
        assertEquals(16, model.snapshot.device.geofenceRadius)
    }

    @Test
    fun vacationCrudAndActivationUseSharedState() {
        val model = model()
        val profile = model.snapshot.activityProfiles.first()
        val trip = VacationTrip(
            name = "Trip",
            startEpochMs = 200,
            endEpochMs = 100,
            profileId = profile.id,
        )
        model.saveVacation(trip)
        val saved = model.snapshot.vacations.first { it.id == trip.id }
        assertEquals(saved.startEpochMs, saved.endEpochMs)
        model.setVacationActive(trip.id, true)
        assertEquals(ControlMode.Vacation, model.snapshot.controlMode)
        assertEquals(profile.heatTo, model.snapshot.device.keepMin)
        assertEquals(1, model.snapshot.vacations.count { it.isActive })
        model.setVacationActive(trip.id, false)
        assertEquals(ControlMode.Schedule, model.snapshot.controlMode)
        model.deleteVacation(trip.id)
        assertFalse(model.snapshot.vacations.any { it.id == trip.id })
    }

    @Test
    fun timelineUsesProgramsWhenPresetsAreDisabled() {
        val model = model()
        model.setDeviceUsePresets(false)
        model.setSystemMode(SystemMode.Heat)
        val program = model.programsFor(ScheduleKind.Heat).first()
        model.selectProgram(program.id, ScheduleKind.Heat)
        assertEquals(program.groups.first().events.size, model.snapshot.todaysTimeline.size)
        assertEquals(model.snapshot.currentPeriod(600)?.heatTo, model.snapshot.device.keepMin)
    }
}
