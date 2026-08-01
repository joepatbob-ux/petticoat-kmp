package com.sensi.petticoat.model

object ReminderEditorConfig {
    val types = listOf("Air Filter", "Humidifier Pad", "UV Lamp", "Maintenance")
    fun durationsFor(basis: ReminderBasis): List<String> = when (basis) {
        ReminderBasis.Runtime -> listOf("100 Hours", "200 Hours", "300 Hours", "500 Hours")
        ReminderBasis.Calendar -> listOf("1 Month", "3 Months", "6 Months", "1 Year")
    }
}

fun ServiceReminder.validationIssue(): String? =
    if (name.isBlank()) "Reminder name is required." else null

object ThermostatSettingsConfig {
    val boostOptions = listOf("Off", "Eco", "Comfort", "Fast")
    val coolingMinRange = 45..80
    val heatingMaxRange = 60..99
    val humidityRange = 20..60
}

object ProfileEditorConfig {
    val heatRange = 45..90
    val coolRange = 50..95
    val colors = listOf(0x30B0C7L, 0xFF9500L, 0xAF52DEL, 0xFF3B30L, 0x34C759L)
    val symbols = listOf("home", "walk", "sleep", "workout", "person")
}
