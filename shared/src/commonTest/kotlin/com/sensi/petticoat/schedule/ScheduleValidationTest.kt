package com.sensi.petticoat.schedule

import com.sensi.petticoat.model.ProgramDayGroup
import com.sensi.petticoat.model.ScheduleDayGroup
import com.sensi.petticoat.model.ScheduleEvent
import com.sensi.petticoat.model.SchedulePreset
import com.sensi.petticoat.model.ScheduleProgram
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ScheduleValidationTest {
    @Test
    fun completePresetIsValid() {
        assertNull(SchedulePreset(name = "Valid").validationIssue())
    }

    @Test
    fun missingDaysAreRejected() {
        val preset = SchedulePreset(
            name = "Missing",
            groups = listOf(
                ScheduleDayGroup(days = setOf(0, 1), events = ScheduleEvent.samples()),
            ),
        )
        assertEquals("Every day must belong to a schedule group.", preset.validationIssue())
    }

    @Test
    fun emptyGroupsAreRejected() {
        val preset = SchedulePreset(
            name = "Empty",
            groups = listOf(ScheduleDayGroup(days = (0..6).toSet(), events = emptyList())),
        )
        assertEquals("Each day group needs at least one event.", preset.validationIssue())
    }

    @Test
    fun programsUseSameValidation() {
        val program = ScheduleProgram(
            name = "Empty",
            groups = listOf(ProgramDayGroup(days = (0..6).toSet(), events = emptyList())),
        )
        assertEquals("Each day group needs at least one event.", program.validationIssue())
    }

    @Test
    fun weekdaySummaryUsesFriendlyGroups() {
        assertEquals("Every day", WeekDay.summary((0..6).toSet()))
        assertEquals("Weekdays", WeekDay.summary((0..4).toSet()))
        assertEquals("Weekend", WeekDay.summary(setOf(5, 6)))
    }
}
