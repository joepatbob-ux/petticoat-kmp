package com.sensi.petticoat.model

/** Epoch millis — platform clock. */
expect fun platformNowMillis(): Long

/** Locale-aware short local time, for example "3:15 PM". */
expect fun platformFormatTime(epochMillis: Long): String

expect fun platformFormatDate(epochMillis: Long): String

expect fun platformFormatDateRange(startEpochMillis: Long, endEpochMillis: Long): String
