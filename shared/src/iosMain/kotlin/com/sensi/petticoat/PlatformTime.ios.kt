package com.sensi.petticoat

import platform.Foundation.NSCalendar
import platform.Foundation.NSCalendarUnitHour
import platform.Foundation.NSCalendarUnitMinute
import platform.Foundation.NSCalendarUnitWeekday
import platform.Foundation.NSDate

actual fun platformNowMinutes(): Int {
    val cal = NSCalendar.currentCalendar
    val comps = cal.components(NSCalendarUnitHour or NSCalendarUnitMinute, fromDate = NSDate())
    return comps.hour.toInt() * 60 + comps.minute.toInt()
}

actual fun platformWeekdayIndex(): Int {
    // NSCalendar weekday: 1=Sunday … 7=Saturday → 0=Monday … 6=Sunday
    val cal = NSCalendar.currentCalendar
    val comps = cal.components(NSCalendarUnitWeekday, fromDate = NSDate())
    return (comps.weekday.toInt() + 5) % 7
}
