package com.sensi.petticoat.model

enum class UsageMode(val label: String) { Cool("Cooling"), Heat("Heating"), Aux("AUX Heat"), Fan("Fan Only") }
enum class UsageRange(val label: String) { Recent("Recent"), Monthly("Monthly") }

data class UsageEntry(
    val id: String = newId(),
    val title: String,
    val minutes: Map<UsageMode, Int>,
    val capacityMinutes: Int = 1440,
    val insufficient: Boolean = false,
) {
    val totalRuntimeMinutes: Int get() = minutes.values.sum()
    fun fraction(mode: UsageMode): Float =
        if (capacityMinutes <= 0) 0f else (minutes[mode] ?: 0).toFloat() / capacityMinutes
}

data class UsagePeriod(val id: String = newId(), val name: String, val entries: List<UsageEntry>)
data class UsageHistory(val recent: List<UsagePeriod>, val monthly: List<UsagePeriod>)

fun formatUsageDuration(minutes: Int): String {
    val hours = minutes / 60
    val remainder = minutes % 60
    return when {
        hours == 0 -> "${remainder}m"
        remainder == 0 -> "${hours}h"
        else -> "${hours}h ${remainder}m"
    }
}

object UsageSample {
    fun history(nowMs: Long = platformNowMillis()): UsageHistory {
        val day = 24L * 60 * 60 * 1000
        fun values(index: Int) = mapOf(
            UsageMode.Cool to 35 + index * 7,
            UsageMode.Heat to 12 + (index % 3) * 9,
            UsageMode.Aux to if (index % 4 == 0) 8 else 0,
            UsageMode.Fan to 20 + index * 3,
        )
        val recentEntries = (0..13).map { offset ->
            UsageEntry(
                title = platformFormatDate(nowMs - offset * day),
                minutes = values(offset),
                insufficient = offset == 11,
            ).let { if (it.insufficient) it.copy(minutes = emptyMap()) else it }
        }
        val monthlyEntries = (0..12).map { offset ->
            UsageEntry(
                title = "Month ${offset + 1}",
                minutes = if (offset == 12) emptyMap() else values(offset).mapValues { it.value * 24 },
                capacityMinutes = 30 * 1440,
                insufficient = offset == 12,
            )
        }
        return UsageHistory(
            recent = listOf(UsagePeriod(name = "Recent", entries = recentEntries)),
            monthly = listOf(UsagePeriod(name = "Last 13 months", entries = monthlyEntries)),
        )
    }
}
