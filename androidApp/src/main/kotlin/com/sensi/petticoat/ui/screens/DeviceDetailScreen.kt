package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Thermostat
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.DeviceTab
import com.sensi.petticoat.ui.components.PlaceholderScreen

/**
 * Device-detail container: a bottom navigation bar over [DeviceTab] with each tab providing
 * its own top bar. Sensors is a full-screen overlay reached from the Control tab.
 * Port of iOS `DeviceTabView.swift`.
 */
@Composable
fun DeviceDetailScreen(
    model: AppModel,
    state: AppState,
) {
    var showSensors by remember { mutableStateOf(false) }
    val onBack = model::clearSelectedDevice

    if (showSensors) {
        SensorsScreen(model = model, state = state, onBack = { showSensors = false })
        return
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Box(modifier = Modifier.weight(1f)) {
            when (state.selectedTab) {
                DeviceTab.Control -> ControlContent(
                    model = model,
                    state = state,
                    onBack = onBack,
                    onOpenSensors = { showSensors = true },
                )
                DeviceTab.Schedule -> AutomationScreen(model = model, state = state, onBack = onBack)
                DeviceTab.Usage -> PlaceholderScreen(title = "Usage", onBack = onBack)
                DeviceTab.Reminders -> RemindersScreen(model = model, state = state, onBack = onBack)
                DeviceTab.Settings -> SettingsScreen(model = model, state = state, onBack = onBack)
            }
        }
        NavigationBar {
            DeviceTab.entries.forEach { tab ->
                NavigationBarItem(
                    selected = state.selectedTab == tab,
                    onClick = { model.setSelectedTab(tab) },
                    icon = {
                        if (tab == DeviceTab.Reminders && state.criticalReminderCount > 0) {
                            BadgedBox(badge = { Badge { Text("${state.criticalReminderCount}") } }) {
                                Icon(iconFor(tab), contentDescription = tab.label)
                            }
                        } else {
                            Icon(iconFor(tab), contentDescription = tab.label)
                        }
                    },
                    label = { Text(tab.label) },
                )
            }
        }
    }
}

private fun iconFor(tab: DeviceTab): ImageVector = when (tab) {
    DeviceTab.Control -> Icons.Outlined.Thermostat
    DeviceTab.Schedule -> Icons.Outlined.CalendarMonth
    DeviceTab.Usage -> Icons.Outlined.BarChart
    DeviceTab.Reminders -> Icons.Outlined.Notifications
    DeviceTab.Settings -> Icons.Outlined.Settings
}
