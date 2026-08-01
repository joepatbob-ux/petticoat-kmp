package com.sensi.petticoat.ui.device

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Assessment
import androidx.compose.material.icons.outlined.Event
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Thermostat
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.DeviceTab
import com.sensi.petticoat.ui.screens.ControlScreen
import com.sensi.petticoat.ui.screens.UsageScreen
import com.sensi.petticoat.ui.screens.reminders.RemindersScreen
import com.sensi.petticoat.ui.screens.schedule.ScheduleScreen
import com.sensi.petticoat.ui.screens.settings.SettingsScreen

@Composable
fun DeviceScaffold(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    Scaffold(
        bottomBar = {
            NavigationBar {
                DeviceTab.entries.forEach { tab ->
                    NavigationBarItem(
                        modifier = Modifier.testTag("device-tab-${tab.name.lowercase()}"),
                        selected = state.selectedTab == tab,
                        onClick = { model.setSelectedTab(tab) },
                        icon = {
                            BadgedBox(
                                badge = {
                                    if (tab == DeviceTab.Reminders && state.criticalReminderCount > 0) {
                                        Badge { Text(state.criticalReminderCount.toString()) }
                                    }
                                },
                            ) {
                                Icon(tab.icon(), contentDescription = tab.label)
                            }
                        },
                        label = { Text(tab.label) },
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(bottom = padding.calculateBottomPadding())) {
            when (state.selectedTab) {
                DeviceTab.Control -> ControlScreen(model, state, onBack)
                DeviceTab.Schedule -> ScheduleScreen(model, state, onBack)
                DeviceTab.Usage -> UsageScreen(model, state, onBack)
                DeviceTab.Reminders -> RemindersScreen(model, state, onBack)
                DeviceTab.Settings -> SettingsScreen(model, state, onBack)
            }
        }
    }
}

private fun DeviceTab.icon(): ImageVector = when (this) {
    DeviceTab.Control -> Icons.Outlined.Thermostat
    DeviceTab.Schedule -> Icons.Outlined.Event
    DeviceTab.Usage -> Icons.Outlined.Assessment
    DeviceTab.Reminders -> Icons.Outlined.Notifications
    DeviceTab.Settings -> Icons.Outlined.Settings
}
