package com.sensi.petticoat.model

import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter
import platform.Foundation.NSDateFormatterNoStyle
import platform.Foundation.NSDateFormatterShortStyle
import platform.Foundation.dateWithTimeIntervalSince1970
import platform.Foundation.timeIntervalSince1970

actual fun platformNowMillis(): Long =
    (NSDate().timeIntervalSince1970 * 1000.0).toLong()

actual fun platformFormatTime(epochMillis: Long): String {
    val formatter = NSDateFormatter().apply {
        dateStyle = NSDateFormatterNoStyle
        timeStyle = NSDateFormatterShortStyle
    }
    return formatter.stringFromDate(
        NSDate.dateWithTimeIntervalSince1970(epochMillis.toDouble() / 1000.0),
    )
}

actual fun platformFormatDate(epochMillis: Long): String {
    val formatter = NSDateFormatter().apply {
        dateStyle = platform.Foundation.NSDateFormatterMediumStyle
        timeStyle = NSDateFormatterNoStyle
    }
    return formatter.stringFromDate(
        NSDate.dateWithTimeIntervalSince1970(epochMillis.toDouble() / 1000.0),
    )
}

actual fun platformFormatDateRange(startEpochMillis: Long, endEpochMillis: Long): String =
    "${platformFormatDate(startEpochMillis)} – ${platformFormatDate(endEpochMillis)}"
