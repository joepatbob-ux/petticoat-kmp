package com.sensi.petticoat

import com.sensi.petticoat.model.InstallCatalog
import com.sensi.petticoat.model.UsageMode
import com.sensi.petticoat.model.UsageSample
import com.sensi.petticoat.model.WireConfigValidator
import com.sensi.petticoat.model.formatUsageDuration
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class UsageAndInstallTest {
    @Test fun usageDurationFormatting() {
        assertEquals("52m", formatUsageDuration(52))
        assertEquals("16h", formatUsageDuration(960))
        assertEquals("16h 52m", formatUsageDuration(1012))
    }

    @Test fun usageHistoryHasRangesAndInsufficientData() {
        val history = UsageSample.history(1_700_000_000_000)
        assertTrue(history.recent.first().entries.any { it.insufficient })
        assertEquals(13, history.monthly.first().entries.size)
        assertTrue(history.recent.first().entries.first().fraction(UsageMode.Cool) > 0)
    }

    @Test fun installCatalogAndWireValidation() {
        assertEquals(5, InstallCatalog.devices.size)
        assertTrue(InstallCatalog.devices.last().isRoomSensor)
        assertTrue(WireConfigValidator.isValid(setOf("R", "W", "Y", "G")))
        assertFalse(WireConfigValidator.isValid(setOf("R", "X")))
        assertTrue("C" in WireConfigValidator.allowed(setOf("R")))
    }

    @Test fun addingDeviceClosesInstallerAndSelectsDevice() {
        val model = AppModel()
        val before = model.snapshot.devices.size
        model.setShowAddDevice(true)
        model.addDevice("Basement")
        assertEquals(before + 1, model.snapshot.devices.size)
        assertEquals("Basement", model.snapshot.device.name)
        assertFalse(model.snapshot.showAddDevice)
    }
}
