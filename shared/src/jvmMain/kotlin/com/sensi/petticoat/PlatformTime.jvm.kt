package com.sensi.petticoat

import java.util.Calendar

actual fun platformNowMinutes(): Int {
    val c = Calendar.getInstance()
    return c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
}

actual fun platformWeekdayIndex(): Int {
    val cal = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
    return (cal + 5) % 7
}
