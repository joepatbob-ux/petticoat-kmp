package com.sensi.petticoat.ui.screens.schedule

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.ActivityProfile
import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.DistanceUnit
import com.sensi.petticoat.model.ProfileEditorConfig
import com.sensi.petticoat.model.ProgramEvent
import com.sensi.petticoat.model.ScheduleEvent
import com.sensi.petticoat.model.ScheduleKind
import com.sensi.petticoat.model.SchedulePreset
import com.sensi.petticoat.model.ScheduleProgram
import com.sensi.petticoat.model.VacationTrip
import com.sensi.petticoat.schedule.WeekDay
import com.sensi.petticoat.schedule.validationIssue
import com.sensi.petticoat.ui.components.schedule.RadialScheduleDial

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleScreen(model: AppModel, state: AppState, onBack: () -> Unit) {
    var page by remember { mutableStateOf("hub") }
    var profileDraft by remember { mutableStateOf<ActivityProfile?>(null) }
    var scheduleDraft by remember { mutableStateOf<SchedulePreset?>(null) }
    var vacationDraft by remember { mutableStateOf<VacationTrip?>(null) }
    val title = when {
        page == "profiles" -> "Activity profiles"
        page == "schedules" -> "Schedules"
        page.startsWith("program:") -> ScheduleKind.valueOf(page.substringAfter(":")).listTitle
        page == "vacations" -> "Vacations"
        page == "geofence" -> "Auto Home/Away"
        else -> "Schedule"
    }
    val back = { if (page == "hub") onBack() else page = "hub" }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            when {
                page == "hub" -> ScheduleHub(model, state) { page = it }
                page == "profiles" -> ProfilesList(
                    state,
                    edit = { profileDraft = it },
                    add = { profileDraft = ActivityProfile.newBlank() },
                    duplicate = model::duplicateProfile,
                    delete = { model.deleteProfile(it.id) },
                )
                page == "schedules" -> SchedulesList(
                    state,
                    select = model::selectSchedule,
                    edit = { scheduleDraft = it },
                    add = { scheduleDraft = SchedulePreset(name = "New Schedule") },
                    duplicate = model::duplicateSchedule,
                    delete = model::deleteSchedule,
                )
                page.startsWith("program:") -> {
                    val kind = ScheduleKind.valueOf(page.substringAfter(":"))
                    ProgramsList(model, state, kind)
                }
                page == "vacations" -> VacationsList(
                    state,
                    toggle = model::setVacationActive,
                    edit = { vacationDraft = it },
                    add = { vacationDraft = VacationTrip.newBlank() },
                    delete = model::deleteVacation,
                )
                page == "geofence" -> GeofenceSettings(model, state)
            }
        }
    }

    profileDraft?.let { draft ->
        ProfileEditor(
            initial = draft,
            onDismiss = { profileDraft = null },
            onSave = { model.saveProfile(it); profileDraft = null },
        )
    }
    scheduleDraft?.let { draft ->
        ScheduleEditor(
            initial = draft,
            onDismiss = { scheduleDraft = null },
            onSave = { model.saveSchedule(it); scheduleDraft = null },
        )
    }
    vacationDraft?.let { draft ->
        VacationEditor(
            initial = draft,
            profiles = state.activityProfiles,
            onDismiss = { vacationDraft = null },
            onSave = { model.saveVacation(it); vacationDraft = null },
        )
    }
}

@Composable
private fun ScheduleHub(model: AppModel, state: AppState, open: (String) -> Unit) {
    val scheduled = state.controlMode == ControlMode.Schedule || state.controlMode == ControlMode.Hold
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(scheduled, { model.setScheduleEnabled(true) }, { Text("Schedule") })
                FilterChip(!scheduled, { model.setScheduleEnabled(false) }, { Text("Off") })
            }
        }
        item {
            ToggleCard("Use presets", state.device.usePresets) {
                model.setDeviceUsePresets(it)
            }
        }
        if (state.device.usePresets) {
            item { NavCard("Activity profiles", "${state.activityProfiles.size} profiles") { open("profiles") } }
            item { NavCard("Schedules", state.scheduleName) { open("schedules") } }
        } else {
            ScheduleKind.entries.forEach { kind ->
                item { NavCard(kind.listTitle, "${state.programsFor(kind).size} programs") { open("program:${kind.name}") } }
            }
        }
        item { ToggleCard("Early start", state.device.earlyStart) { model.setDeviceEarlyStart(it) } }
        item { ToggleCard("Auto Home/Away", state.device.geofenceEnabled) { model.setDeviceGeofenceEnabled(it) } }
        if (state.device.geofenceEnabled) {
            item { NavCard("Geofence radius", state.device.geofenceUnit.label(state.device.geofenceRadius)) { open("geofence") } }
        }
        item { NavCard("Vacations", "${state.vacations.size} saved") { open("vacations") } }
    }
}

@Composable
private fun ProfilesList(
    state: AppState,
    edit: (ActivityProfile) -> Unit,
    add: () -> Unit,
    duplicate: (ActivityProfile) -> Unit,
    delete: (ActivityProfile) -> Unit,
) {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Button(onClick = add) { Icon(Icons.Outlined.Add, null); Text("New profile") } }
        items(state.activityProfiles, key = { it.id }) { profile ->
            Card(onClick = { edit(profile) }) {
                Column(Modifier.padding(16.dp)) {
                    Text(profile.name, style = MaterialTheme.typography.titleMedium)
                    Text("${profile.subtitle} · ${profile.rangeText}")
                    Row {
                        TextButton(onClick = { duplicate(profile) }) { Text("Duplicate") }
                        TextButton(onClick = { delete(profile) }) { Text("Delete") }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfileEditor(initial: ActivityProfile, onDismiss: () -> Unit, onSave: (ActivityProfile) -> Unit) {
    var draft by remember(initial.id) { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit activity profile") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(draft.name, { draft = draft.copy(name = it) }, label = { Text("Name") })
                SetpointButtons("Heat to", draft.heatTo, ProfileEditorConfig.heatRange) {
                    draft = draft.copy(heatTo = it)
                }
                SetpointButtons("Cool to", draft.coolTo, ProfileEditorConfig.coolRange) {
                    draft = draft.copy(coolTo = it)
                }
            }
        },
        confirmButton = { TextButton(enabled = draft.name.isNotBlank(), onClick = { onSave(draft) }) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun SchedulesList(
    state: AppState,
    select: (String) -> Unit,
    edit: (SchedulePreset) -> Unit,
    add: () -> Unit,
    duplicate: (SchedulePreset) -> Unit,
    delete: (String) -> Unit,
) {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Button(onClick = add) { Icon(Icons.Outlined.Add, null); Text("New schedule") } }
        items(state.schedules, key = { it.id }) { schedule ->
            Card {
                ListItem(
                    headlineContent = { Text(schedule.name) },
                    supportingContent = { Text(schedule.groups.joinToString { WeekDay.summary(it.days) }) },
                    leadingContent = {
                        RadioButton(state.activeSchedule?.id == schedule.id, { select(schedule.id) })
                    },
                    trailingContent = {
                        Row {
                            TextButton(onClick = { edit(schedule) }) { Text("Edit") }
                            IconButton(onClick = { delete(schedule.id) }) { Icon(Icons.Outlined.Delete, "Delete") }
                        }
                    },
                )
                TextButton(onClick = { duplicate(schedule) }, modifier = Modifier.padding(horizontal = 12.dp)) {
                    Text("Duplicate")
                }
            }
        }
    }
}

@Composable
private fun ScheduleEditor(initial: SchedulePreset, onDismiss: () -> Unit, onSave: (SchedulePreset) -> Unit) {
    var draft by remember(initial.id) { mutableStateOf(initial) }
    val events = draft.groups.firstOrNull()?.events.orEmpty()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Schedule editor") },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                item { OutlinedTextField(draft.name, { draft = draft.copy(name = it) }, label = { Text("Name") }) }
                item {
                    RadialScheduleDial(events) { id, minutes ->
                        val groups = draft.groups.map { group ->
                            group.copy(events = group.events.map {
                                if (it.id == id) it.copy(startMinutes = minutes) else it
                            }.sortedBy { it.startMinutes })
                        }
                        draft = draft.copy(groups = groups)
                    }
                }
                items(events, key = { it.id }) { event ->
                    Text("${event.timeText}  ${event.name}  ${event.rangeText}")
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = draft.name.isNotBlank() && draft.validationIssue() == null,
                onClick = { onSave(draft) },
            ) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun ProgramsList(model: AppModel, state: AppState, kind: ScheduleKind) {
    val programs = state.programsFor(kind)
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(programs, key = { it.id }) { program ->
            Card {
                ListItem(
                    headlineContent = { Text(program.name) },
                    supportingContent = { Text(program.groups.firstOrNull()?.events?.joinToString { it.setpointText(kind) }.orEmpty()) },
                    leadingContent = {
                        RadioButton(state.selectedProgramIdFor(kind) == program.id, { model.selectProgram(program.id, kind) })
                    },
                    trailingContent = {
                        IconButton(onClick = { model.deleteProgram(program.id, kind) }) {
                            Icon(Icons.Outlined.Delete, "Delete")
                        }
                    },
                )
                Row(Modifier.padding(horizontal = 12.dp)) {
                    TextButton(onClick = { model.duplicateProgram(program, kind) }) { Text("Duplicate") }
                    TextButton(onClick = {
                        val first = program.groups.firstOrNull()?.events?.firstOrNull() ?: return@TextButton
                        val changed = first.withDeadband(heat = first.heatTo + if (kind.editsHeat) 1 else 0)
                        val updated = program.copy(groups = program.groups.mapIndexed { index, group ->
                            if (index == 0) group.copy(events = listOf(changed) + group.events.drop(1)) else group
                        })
                        model.saveProgram(updated, kind)
                    }) { Text("Adjust first event") }
                }
            }
        }
    }
}

@Composable
private fun VacationsList(
    state: AppState,
    toggle: (String, Boolean) -> Unit,
    edit: (VacationTrip) -> Unit,
    add: () -> Unit,
    delete: (String) -> Unit,
) {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Button(onClick = add) { Icon(Icons.Outlined.Add, null); Text("New vacation") } }
        items(state.vacations, key = { it.id }) { trip ->
            Card(onClick = { edit(trip) }) {
                ListItem(
                    headlineContent = { Text(trip.name) },
                    supportingContent = { Text(trip.dateRangeText) },
                    trailingContent = { Switch(trip.isActive, { toggle(trip.id, it) }) },
                )
                TextButton(onClick = { delete(trip.id) }) { Text("Delete") }
            }
        }
    }
}

@Composable
private fun VacationEditor(
    initial: VacationTrip,
    profiles: List<ActivityProfile>,
    onDismiss: () -> Unit,
    onSave: (VacationTrip) -> Unit,
) {
    var draft by remember(initial.id) { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Vacation") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(draft.name, { draft = draft.copy(name = it) }, label = { Text("Name") })
                Text(draft.dateRangeText)
                profiles.forEach { profile ->
                    FilterChip(
                        selected = draft.profileId == profile.id,
                        onClick = { draft = draft.copy(profileId = profile.id) },
                        label = { Text(profile.name) },
                    )
                }
            }
        },
        confirmButton = { TextButton(onClick = { onSave(draft) }) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun GeofenceSettings(model: AppModel, state: AppState) {
    val device = state.device
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text("Radius: ${device.geofenceUnit.label(device.geofenceRadius)}", style = MaterialTheme.typography.titleMedium)
        Slider(
            value = device.geofenceRadius.toFloat(),
            onValueChange = { model.setDeviceGeofenceRadius(it.toInt()) },
            valueRange = device.geofenceUnit.range.first.toFloat()..device.geofenceUnit.range.last.toFloat(),
            steps = device.geofenceUnit.range.count() - 2,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DistanceUnit.entries.forEach { unit ->
                FilterChip(
                    selected = device.geofenceUnit == unit,
                    onClick = { model.setDeviceGeofenceUnit(unit) },
                    label = { Text(unit.name) },
                )
            }
        }
        Card {
            Text(
                "The thermostat switches between Home and Away when your phone crosses this boundary.",
                modifier = Modifier.padding(18.dp),
            )
        }
    }
}

@Composable
private fun ToggleCard(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Card {
        ListItem(headlineContent = { Text(title) }, trailingContent = { Switch(checked, onChange) })
    }
}

@Composable
private fun NavCard(title: String, detail: String, onClick: () -> Unit) {
    Card(onClick = onClick) {
        ListItem(
            headlineContent = { Text(title) },
            supportingContent = { Text(detail) },
            trailingContent = { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, null) },
        )
    }
}

@Composable
private fun SetpointButtons(title: String, value: Int, range: IntRange, onChange: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("$title $value°")
        Row {
            OutlinedButton(onClick = { onChange((value - 1).coerceIn(range)) }) { Text("−") }
            OutlinedButton(onClick = { onChange((value + 1).coerceIn(range)) }) { Text("+") }
        }
    }
}
