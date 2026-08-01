package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.RadioButtonChecked
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.ProgramDayGroup
import com.sensi.petticoat.model.ProgramEvent
import com.sensi.petticoat.model.ScheduleKind
import com.sensi.petticoat.model.ScheduleProgram
import com.sensi.petticoat.model.SetpointConfig
import com.sensi.petticoat.model.formatMinutes
import com.sensi.petticoat.ui.components.DayPicker
import com.sensi.petticoat.ui.components.RowDivider
import com.sensi.petticoat.ui.components.SectionHeader
import com.sensi.petticoat.ui.components.SettingsCard
import com.sensi.petticoat.ui.components.StepperRow
import com.sensi.petticoat.ui.components.TimePickerDialog

/**
 * Per-mode (Heat/Cool/Auto) program list + editor. Port of iOS `ProgramScheduleFlow.swift`
 * (the non-preset, setpoint-based schedule flow — no radial dial). Backed by the shared
 * programs[kind] map and its select/save/delete/duplicate methods.
 */
@Composable
fun ProgramScheduleScreen(
    model: AppModel,
    state: AppState,
    kind: ScheduleKind,
    onBack: () -> Unit,
) {
    var editing by remember { mutableStateOf<ScheduleProgram?>(null) }

    val target = editing
    if (target != null) {
        ProgramEditor(
            initial = target,
            onSave = {
                model.saveProgram(it, kind)
                editing = null
            },
            onBack = { editing = null },
        )
        return
    }

    ProgramList(
        model = model,
        state = state,
        kind = kind,
        onBack = onBack,
        onEdit = { editing = it },
        onNew = { editing = ScheduleProgram.makeSample("New ${kind.name} Program") },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProgramList(
    model: AppModel,
    state: AppState,
    kind: ScheduleKind,
    onBack: () -> Unit,
    onEdit: (ScheduleProgram) -> Unit,
    onNew: () -> Unit,
) {
    val programs = state.programsFor(kind)
    val selectedId = state.selectedProgramIdFor(kind)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(kind.listTitle) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onNew) {
                        Icon(Icons.Outlined.Add, contentDescription = "New program")
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
        ) {
            SettingsCard {
                programs.forEachIndexed { index, program ->
                    if (index > 0) RowDivider()
                    ProgramRow(
                        program = program,
                        selected = program.id == selectedId,
                        onSelect = { model.selectProgram(program.id, kind) },
                        onEdit = { onEdit(program) },
                        onDuplicate = { model.duplicateProgram(program, kind) },
                        onDelete = { model.deleteProgram(program.id, kind) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ProgramRow(
    program: ScheduleProgram,
    selected: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
    onDuplicate: () -> Unit,
    onDelete: () -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onSelect) {
            Icon(
                if (selected) Icons.Outlined.RadioButtonChecked else Icons.Outlined.RadioButtonUnchecked,
                contentDescription = if (selected) "Selected" else "Select",
                tint = if (selected) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            program.name,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier
                .weight(1f)
                .clickable(onClick = onEdit),
        )
        IconButton(onClick = { menuOpen = true }) {
            Icon(Icons.Outlined.MoreVert, contentDescription = "More")
        }
        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
            DropdownMenuItem(text = { Text("Edit") }, onClick = { onEdit(); menuOpen = false })
            DropdownMenuItem(text = { Text("Duplicate") }, onClick = { onDuplicate(); menuOpen = false })
            DropdownMenuItem(text = { Text("Delete") }, onClick = { onDelete(); menuOpen = false })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProgramEditor(
    initial: ScheduleProgram,
    onSave: (ScheduleProgram) -> Unit,
    onBack: () -> Unit,
) {
    var program by remember(initial.id) { mutableStateOf(initial) }
    // (groupIndex, event-or-null-for-new) currently being edited.
    var editingEvent by remember { mutableStateOf<Pair<Int, ProgramEvent?>?>(null) }

    fun updateGroup(gi: Int, transform: (ProgramDayGroup) -> ProgramDayGroup) {
        program = program.copy(
            groups = program.groups.mapIndexed { i, g -> if (i == gi) transform(g) else g },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (initial.name.isBlank()) "New Program" else "Edit Program") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Cancel")
                    }
                },
                actions = {
                    TextButton(onClick = { onSave(program.copy(name = program.name.ifBlank { "Program" })) }) {
                        Text("Save")
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
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            OutlinedTextField(
                value = program.name,
                onValueChange = { program = program.copy(name = it) },
                label = { Text("Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            program.groups.forEachIndexed { gi, group ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    SectionHeader("Days")
                    DayPicker(
                        selected = group.days,
                        onToggle = { day ->
                            updateGroup(gi) {
                                it.copy(days = if (day in it.days) it.days - day else it.days + day)
                            }
                        },
                    )
                    SettingsCard {
                        val sorted = group.events.sortedBy { it.startMinutes }
                        sorted.forEachIndexed { index, event ->
                            if (index > 0) RowDivider()
                            EventRow(event = event, onClick = { editingEvent = gi to event })
                        }
                    }
                    TextButton(onClick = { editingEvent = gi to null }) {
                        Icon(Icons.Outlined.Add, contentDescription = null)
                        Spacer(Modifier.height(0.dp))
                        Text("Add Event")
                    }
                }
            }
        }
    }

    val editTarget = editingEvent
    if (editTarget != null) {
        val (gi, event) = editTarget
        ProgramEventEditor(
            initial = event,
            onSave = { updated ->
                updateGroup(gi) { g ->
                    val list = g.events.toMutableList()
                    val idx = list.indexOfFirst { it.id == updated.id }
                    if (idx >= 0) list[idx] = updated else list.add(updated)
                    g.copy(events = list.sortedBy { it.startMinutes })
                }
                editingEvent = null
            },
            onDelete = event?.let {
                {
                    updateGroup(gi) { g -> g.copy(events = g.events.filterNot { e -> e.id == it.id }) }
                    editingEvent = null
                }
            },
            onDismiss = { editingEvent = null },
        )
    }
}

@Composable
private fun EventRow(event: ProgramEvent, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            event.timeText,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Text(
            "Heat ${event.heatTo}° · Cool ${event.coolTo}°",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProgramEventEditor(
    initial: ProgramEvent?,
    onSave: (ProgramEvent) -> Unit,
    onDelete: (() -> Unit)?,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var startMinutes by remember { mutableStateOf(initial?.startMinutes ?: (12 * 60)) }
    var heatTo by remember { mutableStateOf(initial?.heatTo ?: 68) }
    var coolTo by remember { mutableStateOf(initial?.coolTo ?: 76) }
    var showTimePicker by remember { mutableStateOf(false) }

    val lo = SetpointConfig.MIN_TEMP
    val hi = SetpointConfig.MAX_TEMP
    val gap = SetpointConfig.DEADBAND

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                if (initial == null) "New Event" else "Edit Event",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )

            SettingsCard {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showTimePicker = true }
                        .padding(horizontal = 16.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "Start Time",
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.weight(1f),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        formatMinutes(startMinutes),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                RowDivider()
                StepperRow(
                    title = "Heat To",
                    valueText = "$heatTo°",
                    onDecrement = { heatTo = (heatTo - 1).coerceIn(lo, hi - gap) },
                    onIncrement = {
                        heatTo = (heatTo + 1).coerceIn(lo, hi - gap)
                        if (coolTo < heatTo + gap) coolTo = heatTo + gap
                    },
                )
                RowDivider()
                StepperRow(
                    title = "Cool To",
                    valueText = "$coolTo°",
                    onDecrement = {
                        coolTo = (coolTo - 1).coerceIn(lo + gap, hi)
                        if (heatTo > coolTo - gap) heatTo = coolTo - gap
                    },
                    onIncrement = { coolTo = (coolTo + 1).coerceIn(lo + gap, hi) },
                )
            }

            Button(
                onClick = {
                    val result = (initial ?: ProgramEvent(startMinutes = startMinutes, heatTo = heatTo, coolTo = coolTo))
                        .copy(startMinutes = startMinutes, heatTo = heatTo, coolTo = coolTo)
                    onSave(result)
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Save") }

            if (onDelete != null) {
                TextButton(onClick = onDelete, modifier = Modifier.fillMaxWidth()) {
                    Text("Delete", color = Color(0xFFE0392B))
                }
            }
        }
    }

    if (showTimePicker) {
        TimePickerDialog(
            initialMinutes = startMinutes,
            onConfirm = {
                startMinutes = it
                showTimePicker = false
            },
            onDismiss = { showTimePicker = false },
        )
    }
}
