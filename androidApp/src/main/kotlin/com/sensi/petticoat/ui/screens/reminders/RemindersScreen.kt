package com.sensi.petticoat.ui.screens.reminders

import android.content.Intent
import android.net.Uri
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
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.ReminderBasis
import com.sensi.petticoat.model.ReminderEditorConfig
import com.sensi.petticoat.model.ServiceReminder
import com.sensi.petticoat.model.platformNowMillis

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RemindersScreen(model: AppModel, state: AppState, onBack: () -> Unit) {
    var editor by remember { mutableStateOf<ServiceReminder?>(null) }
    var creating by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Reminders") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { creating = true }) {
                Icon(Icons.Outlined.Add, "Add reminder")
            }
        },
    ) { padding ->
        if (state.serviceReminders.isEmpty()) {
            Column(
                Modifier.fillMaxSize().padding(padding).padding(32.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Outlined.Notifications, null)
                Text("No reminders", style = MaterialTheme.typography.headlineSmall)
                Text("Add filter changes or HVAC maintenance reminders.")
                Button(onClick = { creating = true }) { Text("Add reminder") }
            }
        } else {
            LazyColumn(
                Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(state.serviceReminders, key = { it.id }) { reminder ->
                    ReminderCard(
                        reminder = reminder,
                        contractorPhone = state.contractor.phoneDigits,
                        onComplete = { model.completeReminder(reminder.id) },
                        onEdit = { editor = reminder },
                        onDelete = { model.deleteReminder(reminder.id) },
                    )
                }
            }
        }
    }

    if (creating || editor != null) {
        ReminderEditorSheet(
            initial = editor,
            onDismiss = { creating = false; editor = null },
            onSave = {
                model.saveReminder(it)
                creating = false
                editor = null
            },
        )
    }
}

@Composable
private fun ReminderCard(
    reminder: ServiceReminder,
    contractorPhone: String,
    onComplete: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val context = LocalContext.current
    Card(onClick = onEdit, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(reminder.name, style = MaterialTheme.typography.titleMedium)
                IconButton(onClick = onDelete) {
                    Icon(Icons.Outlined.Delete, "Delete ${reminder.name}")
                }
            }
            LinearProgressIndicator(
                progress = { reminder.lifeRemaining.toFloat() },
                modifier = Modifier.fillMaxWidth(),
                color = if (reminder.isCritical) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.primary,
            )
            Text("${(reminder.lifeRemaining * 100).toInt()}% life remaining")
            Text("Next service: ${reminder.nextServiceText}")
            if (reminder.spec.isNotBlank()) Text(reminder.spec)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledTonalButton(onClick = onComplete) { Text("Mark complete") }
                if (reminder.hasContractor && contractorPhone.isNotBlank()) {
                    OutlinedButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$contractorPhone")))
                    }) { Text("Call contractor") }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderEditorSheet(
    initial: ServiceReminder?,
    onDismiss: () -> Unit,
    onSave: (ServiceReminder) -> Unit,
) {
    var name by remember(initial?.id) { mutableStateOf(initial?.name.orEmpty()) }
    var type by remember(initial?.id) { mutableStateOf(initial?.type ?: ReminderEditorConfig.types.first()) }
    var basis by remember(initial?.id) { mutableStateOf(initial?.basedOn ?: ReminderBasis.Runtime) }
    var duration by remember(initial?.id) {
        mutableStateOf(initial?.durationText ?: ReminderEditorConfig.durationsFor(basis).first())
    }
    val now = platformNowMillis()

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier.fillMaxWidth().padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(if (initial == null) "New reminder" else "Edit reminder", style = MaterialTheme.typography.headlineSmall)
            OutlinedTextField(name, { name = it }, label = { Text("Name") }, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(type, { type = it }, label = { Text("Type") }, modifier = Modifier.fillMaxWidth())
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReminderBasis.entries.forEach { option ->
                    OutlinedButton(onClick = {
                        basis = option
                        duration = ReminderEditorConfig.durationsFor(option).first()
                    }) { Text(option.name) }
                }
            }
            OutlinedTextField(duration, { duration = it }, label = { Text("Duration") }, modifier = Modifier.fillMaxWidth())
            Button(
                enabled = name.isNotBlank(),
                onClick = {
                    onSave(
                        initial?.copy(
                            name = name.trim(),
                            type = type,
                            basedOn = basis,
                            durationText = duration,
                        ) ?: ServiceReminder(
                            name = name.trim(),
                            type = type,
                            basedOn = basis,
                            durationText = duration,
                            nextServiceEpochMs = now + 90L * 24 * 60 * 60 * 1000,
                            spec = "",
                            lifeRemaining = 1.0,
                        ),
                    )
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Save") }
        }
    }
}
