package com.sensi.petticoat.model

import java.text.DateFormat
import java.util.Date

actual fun platformNowMillis(): Long = System.currentTimeMillis()

actual fun platformFormatTime(epochMillis: Long): String =
    DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(epochMillis))

actual fun platformFormatDate(epochMillis: Long): String =
    DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(epochMillis))

actual fun platformFormatDateRange(startEpochMillis: Long, endEpochMillis: Long): String =
    "${platformFormatDate(startEpochMillis)} – ${platformFormatDate(endEpochMillis)}"
