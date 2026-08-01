package com.sensi.petticoat.model

import java.text.DateFormat
import java.util.Date

actual fun platformNowMillis(): Long = System.currentTimeMillis()

actual fun platformFormatTime(epochMillis: Long): String =
    DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(epochMillis))
