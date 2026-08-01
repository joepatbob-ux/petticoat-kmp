package com.sensi.petticoat

import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.HVACActivity
import com.sensi.petticoat.model.SetpointBound
import com.sensi.petticoat.model.SystemMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AppModelTest {
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
}
