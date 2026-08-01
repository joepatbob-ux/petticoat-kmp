package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.model.ReminderBasis
import com.sensi.petticoat.model.ServiceReminder
import com.sensi.petticoat.ui.components.PillOption
import com.sensi.petticoat.ui.components.PillSegmentedSelector
import com.sensi.petticoat.ui.components.SectionHeader

/**
 * Add/edit editor for a [ServiceReminder]. When [initial] is null a new reminder is created.
 * Port of iOS `ReminderEditor` (RemindersFlow.swift).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReminderEditor(
    initial: ServiceReminder?,
    onSave: (ServiceReminder) -> Unit,
    onDelete: (() -> Unit)?,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var type by remember { mutableStateOf(initial?.type ?: "Air Filter") }
    var basis by remember { mutableStateOf(initial?.basedOn ?: ReminderBasis.Runtime) }
    var duration by remember { mutableStateOf(initial?.durationText ?: "300 Hours") }
    var spec by remember { mutableStateOf(initial?.spec ?: "") }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                if (initial == null) "New Reminder" else "Edit Reminder",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = type,
                onValueChange = { type = it },
                label = { Text("Type") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            SectionHeader("Based On")
            PillSegmentedSelector(
                options = ReminderBasis.entries.map { PillOption(it, it.name) },
                selected = basis,
                onSelect = { basis = it },
            )
            OutlinedTextField(
                value = duration,
                onValueChange = { duration = it },
                label = { Text("Duration") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = spec,
                onValueChange = { spec = it },
                label = { Text("Notes / spec") },
                modifier = Modifier.fillMaxWidth(),
            )

            Button(
                onClick = {
                    val now = System.currentTimeMillis()
                    val result = (initial ?: ServiceReminder(
                        name = "",
                        type = "",
                        basedOn = ReminderBasis.Runtime,
                        durationText = "",
                        nextServiceEpochMs = now + 90L * 24 * 60 * 60 * 1000,
                        spec = "",
                        lifeRemaining = 1.0,
                    )).copy(
                        name = name.ifBlank { "Reminder" },
                        type = type,
                        basedOn = basis,
                        durationText = duration,
                        spec = spec,
                    )
                    onSave(result)
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Save") }

            if (onDelete != null) {
                TextButton(
                    onClick = onDelete,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Delete", color = Color(0xFFE0392B)) }
            }
        }
    }
}
