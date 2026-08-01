package com.sensi.petticoat.model

/**
 * A single usage/runtime entry (one day in the Recent tab, or one month in the Monthly
 * Archive tab) for the Usage screen. Runtime is broken down by HVAC mode in minutes.
 * Mirrors the iOS `UsageSample` prototype data; replace [recent]/[monthly] with a real
 * runtime-history API when wiring production data.
 */
data class UsageSample(
    val id: String = newId(),
    /** Row title, e.g. "Today", "Thursday, 1st", or "May". */
    val label: String,
    /** Month bucket the row belongs to, e.g. "June". */
    val monthGroup: String,
    val coolMinutes: Int,
    val heatMinutes: Int,
    val auxMinutes: Int,
    val fanMinutes: Int,
    /** Supporting text, e.g. "Keep Between: 70 • 75". Empty when [hasData] is false. */
    val keepText: String,
    /** Trailing supporting text, e.g. "As of 9:30 AM". */
    val asOf: String = "As of 9:30 AM",
    val hasData: Boolean = true,
) {
    val totalMinutes: Int get() = coolMinutes + heatMinutes + auxMinutes + fanMinutes

    companion object {
        private fun day(
            label: String,
            month: String,
            cool: Int,
            heat: Int,
            aux: Int,
            fan: Int,
            keep: String = "Keep Between: 70 • 75",
        ) = UsageSample(
            label = label,
            monthGroup = month,
            coolMinutes = cool,
            heatMinutes = heat,
            auxMinutes = aux,
            fanMinutes = fan,
            keepText = keep,
        )

        private fun empty(label: String, month: String) = UsageSample(
            label = label,
            monthGroup = month,
            coolMinutes = 0,
            heatMinutes = 0,
            auxMinutes = 0,
            fanMinutes = 0,
            keepText = "Insufficient Data",
            hasData = false,
        )

        /** Recent daily entries, grouped by month (newest first). */
        fun recent(): List<UsageSample> = listOf(
            day("Today", "June", cool = 612, heat = 240, aux = 90, fan = 150),
            empty("Thursday, 1st", "June"),
            day("Wednesday, 27th", "May", cool = 1012, heat = 1012, aux = 1012, fan = 1012),
            day("Tuesday, 26th", "May", cool = 720, heat = 300, aux = 0, fan = 180),
            empty("Monday, 25th", "May"),
        )

        /** Monthly aggregates for the archive tab. */
        fun monthly(): List<UsageSample> = listOf(
            UsageSample(label = "June", monthGroup = "2024", coolMinutes = 8200, heatMinutes = 1200, auxMinutes = 300, fanMinutes = 2100, keepText = "Avg 70 • 75"),
            UsageSample(label = "May", monthGroup = "2024", coolMinutes = 6400, heatMinutes = 2600, auxMinutes = 500, fanMinutes = 1900, keepText = "Avg 70 • 75"),
            UsageSample(label = "April", monthGroup = "2024", coolMinutes = 2100, heatMinutes = 5200, auxMinutes = 1400, fanMinutes = 1600, keepText = "Avg 68 • 74"),
        )
    }
}
