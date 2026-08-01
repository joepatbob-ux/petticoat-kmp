package com.sensi.petticoat.schedule

import com.sensi.petticoat.model.SchedulePreset
import com.sensi.petticoat.model.ScheduleProgram

object ScheduleEditorLimits {
    const val MIN_EVENTS = 1
    const val MAX_EVENTS = 8
    const val SNAP_MINUTES = 15
    const val MIN_DURATION_MINUTES = 60
}

fun SchedulePreset.validationIssue(): String? = validateGroups(groups.map {
    it.days to it.events.size
})

fun ScheduleProgram.validationIssue(): String? = validateGroups(groups.map {
    it.days to it.events.size
})

private fun validateGroups(groups: List<Pair<Set<Int>, Int>>): String? {
    if ((0..6).any { day -> groups.none { day in it.first } }) {
        return "Every day must belong to a schedule group."
    }
    if (groups.any { it.second < ScheduleEditorLimits.MIN_EVENTS }) {
        return "Each day group needs at least one event."
    }
    if (groups.any { it.second > ScheduleEditorLimits.MAX_EVENTS }) {
        return "Each day group can have at most ${ScheduleEditorLimits.MAX_EVENTS} events."
    }
    return null
}

object WeekDay {
    val labels = listOf("M", "T", "W", "T", "F", "S", "S")
    val names = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    val shortNames = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

    fun summary(days: Set<Int>): String = when {
        days == (0..6).toSet() -> "Every day"
        days == (0..4).toSet() -> "Weekdays"
        days == setOf(5, 6) -> "Weekend"
        else -> days.sorted().joinToString(", ") { shortNames[it.coerceIn(0, 6)] }
    }
}
