package com.sensi.petticoat.model

import platform.Foundation.NSDate
import platform.Foundation.timeIntervalSince1970

actual fun platformNowMillis(): Long =
    (NSDate().timeIntervalSince1970 * 1000.0).toLong()
