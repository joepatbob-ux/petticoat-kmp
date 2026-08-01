package com.sensi.petticoat.model

import kotlin.random.Random

/** RFC 4122-shaped UUID string, generated without another common dependency. */
fun newId(): String {
    val hex = "0123456789abcdef"
    val chars = CharArray(36)
    for (index in chars.indices) {
        chars[index] = when (index) {
            8, 13, 18, 23 -> '-'
            14 -> '4' // version 4
            19 -> "89ab"[Random.nextInt(4)] // RFC 4122 variant
            else -> hex[Random.nextInt(16)]
        }
    }
    return chars.concatToString()
}

enum class SystemMode {
    Cool, Heat, AuxHeat, Auto, Off;

    val label: String
        get() = when (this) {
            Cool -> "Cool"
            Heat -> "Heat"
            AuxHeat -> "AUX"
            Auto -> "Auto"
            Off -> "Off"
        }

    val setpointLabel: String
        get() = when (this) {
            Heat, AuxHeat -> "Heat To"
            Cool -> "Cool To"
            else -> "Keep Between"
        }

    val isRangeSetpoint: Boolean get() = this == Auto || this == Off
    val wireValue: String get() = name
}

enum class FanMode {
    Auto, On;

    val label: String get() = if (this == Auto) "Auto" else "On"
    val wireValue: String get() = name
}

enum class HVACActivity { Idle, Heating, Cooling; val wireValue: String get() = name }

enum class ControlMode {
    Standard, Schedule, Hold, Activity, Vacation;
    val wireValue: String get() = name
}

enum class SetpointBound { Low, High; val wireValue: String get() = name }

object SetpointConfig {
    const val MIN_TEMP = 45
    const val MAX_TEMP = 95
    const val DEADBAND = 2
}

enum class HoldDuration {
    Indefinite, OneHour, TwoHours, ThreeHours, SixHours, TwelveHours;

    val label: String
        get() = when (this) {
            Indefinite -> "Indefinite"
            OneHour -> "1 Hour"
            TwoHours -> "2 Hours"
            ThreeHours -> "3 Hours"
            SixHours -> "6 Hours"
            TwelveHours -> "12 Hours"
        }

    val hours: Int?
        get() = when (this) {
            Indefinite -> null
            OneHour -> 1
            TwoHours -> 2
            ThreeHours -> 3
            SixHours -> 6
            TwelveHours -> 12
        }
    val wireValue: String get() = name
}

enum class HomeSize {
    Small, Medium, Large, XLarge;

    val label: String
        get() = when (this) {
            Small -> "Small (< 1,000 sq ft)"
            Medium -> "Medium (1,000–2,500 sq ft)"
            Large -> "Large (2,500–4,000 sq ft)"
            XLarge -> "Very Large (4,000+ sq ft)"
        }

    val rateMultiplier: Double
        get() = when (this) {
            Small -> 1.35
            Medium -> 1.0
            Large -> 0.72
            XLarge -> 0.50
        }
    val wireValue: String get() = name
}

enum class HVACSystemType {
    GasFurnace, ElectricFurnace, HeatPump, AuxHeat;

    val label: String
        get() = when (this) {
            GasFurnace -> "Gas Furnace"
            ElectricFurnace -> "Electric Furnace / Heat Strip"
            HeatPump -> "Heat Pump"
            AuxHeat -> "Auxiliary / Emergency Heat"
        }

    val heatingFactor: Double
        get() = when (this) {
            GasFurnace -> 1.25
            ElectricFurnace -> 1.0
            HeatPump -> 0.90
            AuxHeat -> 0.80
        }
    val wireValue: String get() = name
}

enum class DashboardSection {
    Thermostats, Spotlight;

    val title: String get() = if (this == Thermostats) "Thermostats" else "Spotlight"
    val wireValue: String get() = name
}

enum class StepperStyle {
    PlusMinus, Chevron;

    val label: String
        get() = when (this) {
            PlusMinus -> "Plus / Minus"
            Chevron -> "Chevrons"
        }
    val wireValue: String get() = name
}

enum class AppAppearance {
    Light, System, Dark;

    val title: String
        get() = when (this) {
            Light -> "Light"
            System -> "System"
            Dark -> "Dark"
        }
    val wireValue: String get() = name
}

enum class TemperatureUnit {
    Fahrenheit, Celsius;

    val label: String get() = if (this == Fahrenheit) "°F" else "°C"

    fun convert(fahrenheit: Int): Double {
        if (this == Fahrenheit) return fahrenheit.toDouble()
        val c = (fahrenheit - 32) * 5.0 / 9.0
        return kotlin.math.round(c * 2) / 2.0
    }

    fun format(fahrenheit: Int): String {
        val v = convert(fahrenheit)
        return if (v % 1.0 == 0.0) v.toInt().toString() else v.toString()
    }
    val wireValue: String get() = name
}

enum class DeviceTab {
    Control, Schedule, Usage, Reminders, Settings;

    val label: String
        get() = when (this) {
            Control -> "Control"
            Schedule -> "Schedule"
            Usage -> "Usage"
            Reminders -> "Reminders"
            Settings -> "Settings"
        }
    val wireValue: String get() = name
}

enum class ScheduleKind {
    Heat, Cool, Auto;

    val listTitle: String
        get() = when (this) {
            Heat -> "Heating Schedule"
            Cool -> "Cooling Schedule"
            Auto -> "Auto Schedule"
        }
    val wireValue: String get() = name
    val detail: String get() = when (this) {
        Heat -> "Heat"
        Cool -> "Cool"
        Auto -> "Auto"
    }
    val editsHeat: Boolean get() = this != Cool
    val editsCool: Boolean get() = this != Heat
}

enum class ReminderBasis { Runtime, Calendar; val wireValue: String get() = name }

enum class SpotlightKind { Promotional, Generic, Partner; val wireValue: String get() = name }

enum class DistanceUnit {
    Miles, Kilometers;

    val wireValue: String get() = name
    val range: IntRange get() = if (this == Miles) 1..10 else 1..16
    fun label(value: Int): String =
        "$value ${if (this == Miles) if (value == 1) "mile" else "miles" else "km"}"
}
