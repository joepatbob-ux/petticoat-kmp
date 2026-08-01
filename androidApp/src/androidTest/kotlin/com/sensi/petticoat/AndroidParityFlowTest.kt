package com.sensi.petticoat

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidParityFlowTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private fun openDevice() {
        composeRule.waitUntil(5_000) {
            composeRule.onAllNodes(hasText("Login")).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag("login-button").performClick()
        composeRule.onNodeWithTag("thermostat-home").performClick()
    }

    @Test
    fun allDeviceTabsAreReachable() {
        openDevice()
        composeRule.onNodeWithTag("device-tab-schedule").performClick()
        composeRule.onNodeWithTag("device-tab-schedule").assertIsSelected()
        composeRule.onNodeWithTag("device-tab-reminders").performClick()
        composeRule.onNodeWithTag("device-tab-reminders").assertIsSelected()
        composeRule.onNodeWithTag("device-tab-settings").performClick()
        composeRule.onNodeWithTag("device-tab-settings").assertIsSelected()
    }

    @Test
    fun scheduleAndSettingsDrillInsWork() {
        openDevice()
        composeRule.onNodeWithTag("device-tab-schedule").performClick()
        composeRule.onNodeWithText("Activity profiles").performClick()
        composeRule.onNodeWithText("New profile").assertIsDisplayed()

        composeRule.onNodeWithTag("device-tab-settings").performClick()
        composeRule.onNodeWithText("Display options").performClick()
        composeRule.onNodeWithText("Continuous backlight").assertIsDisplayed()
    }
}
