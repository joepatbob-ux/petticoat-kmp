package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.PowerSettingsNew
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.ScheduleKind
import com.sensi.petticoat.ui.components.NavRow
import com.sensi.petticoat.ui.components.PillOption
import com.sensi.petticoat.ui.components.PillSegmentedSelector
import com.sensi.petticoat.ui.components.PlaceholderScreen
import com.sensi.petticoat.ui.components.RowDivider
import com.sensi.petticoat.ui.components.SectionHeader
import com.sensi.petticoat.ui.components.SettingsCard
import com.sensi.petticoat.ui.components.ToggleRow

private enum class ScheduleMode { Schedule, Off }
private enum class AutomationRoute { Menu, Presets, Programs, Profiles, Geofence, Vacations }

@Composable
private fun ProgramRowFor(
    state: AppState,
    kind: ScheduleKind,
    title: String,
    onClick: () -> Unit,
) {
    val selectedId = state.selectedProgramIdFor(kind)
    val name = state.programsFor(kind).firstOrNull { it.id == selectedId }?.name
    NavRow(title, value = name, onClick = onClick)
}

/**
 * Schedule/Automation tab landing. Toggles are wired to shared state; the drill-in rows
 * navigate to deferred placeholder screens (Presets, Programs, Profiles, Geofence, Vacations)
 * until later milestones. Port of iOS `ScheduleView.swift`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AutomationScreen(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    var route by remember { mutableStateOf(AutomationRoute.Menu) }
    var programKind by remember { mutableStateOf(ScheduleKind.Heat) }

    when (route) {
        AutomationRoute.Menu -> Unit
        AutomationRoute.Presets -> { PlaceholderScreen("Schedules") { route = AutomationRoute.Menu }; return }
        AutomationRoute.Programs -> {
            ProgramScheduleScreen(model, state, programKind) { route = AutomationRoute.Menu }
            return
        }
        AutomationRoute.Profiles -> {
            ActivityProfilesScreen(model, state) { route = AutomationRoute.Menu }
            return
        }
        AutomationRoute.Geofence -> { PlaceholderScreen("Auto Home/Away") { route = AutomationRoute.Menu }; return }
        AutomationRoute.Vacations -> { PlaceholderScreen("Vacations") { route = AutomationRoute.Menu }; return }
    }

    val device = state.device
    val scheduleMode = if (state.controlMode == ControlMode.Standard) ScheduleMode.Off else ScheduleMode.Schedule

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(device.name) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PillSegmentedSelector(
                options = listOf(
                    PillOption(ScheduleMode.Schedule, "Schedule", Icons.Outlined.CalendarMonth),
                    PillOption(ScheduleMode.Off, "Off", Icons.Outlined.PowerSettingsNew),
                ),
                selected = scheduleMode,
                onSelect = { model.setScheduleEnabled(it == ScheduleMode.Schedule) },
            )

            SectionHeader("Schedule")
            SettingsCard {
                ToggleRow("Use Presets", device.usePresets) { model.setDeviceUsePresets(it) }
                RowDivider()
                if (device.usePresets) {
                    NavRow("Schedules", value = state.scheduleName) { route = AutomationRoute.Presets }
                    RowDivider()
                    NavRow("Activity Profiles", value = "${state.activityProfiles.size}") {
                        route = AutomationRoute.Profiles
                    }
                } else {
                    ProgramRowFor(state, ScheduleKind.Heat, "Heating Schedule") {
                        programKind = ScheduleKind.Heat
                        route = AutomationRoute.Programs
                    }
                    RowDivider()
                    ProgramRowFor(state, ScheduleKind.Cool, "Cooling Schedule") {
                        programKind = ScheduleKind.Cool
                        route = AutomationRoute.Programs
                    }
                    RowDivider()
                    ProgramRowFor(state, ScheduleKind.Auto, "Auto Schedule") {
                        programKind = ScheduleKind.Auto
                        route = AutomationRoute.Programs
                    }
                }
            }

            SectionHeader("Options")
            SettingsCard {
                ToggleRow("Early Start", device.earlyStart) { model.setDeviceEarlyStart(it) }
                RowDivider()
                ToggleRow("Auto Home/Away", device.geofenceEnabled) { model.setDeviceGeofenceEnabled(it) }
                if (device.geofenceEnabled) {
                    RowDivider()
                    NavRow("Geofence Radius") { route = AutomationRoute.Geofence }
                }
            }

            SettingsCard {
                NavRow("Vacations") { route = AutomationRoute.Vacations }
            }
        }
    }
}
