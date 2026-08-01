package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.FanMode
import com.sensi.petticoat.model.HoldDuration
import com.sensi.petticoat.model.RoomSensor
import com.sensi.petticoat.model.SystemMode

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModeSheet(model: AppModel, state: AppState, onDismiss: () -> Unit) {
    val device = state.device
    ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.testTag("mode-sheet")) {
        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("System mode", style = MaterialTheme.typography.titleLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                SystemMode.entries.forEach {
                    FilterChip(device.systemMode == it, { model.setSystemMode(it) }, { Text(it.label) })
                }
            }
            Text("Fan", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FanMode.entries.forEach {
                    FilterChip(device.fanMode == it, { model.setFanMode(it) }, { Text(it.label) })
                }
            }
            if (device.fanMode == FanMode.On) {
                DurationChips(device.fanHoldDuration, { model.setDeviceFanHoldDuration(it) }, "fan-run-for-picker")
            } else {
                ListItem(
                    headlineContent = { Text("Circulate fan") },
                    trailingContent = {
                        Switch(
                            device.circulateFan,
                            { model.setDeviceCirculateFan(it) },
                            modifier = Modifier.testTag("circulate-toggle"),
                        )
                    },
                )
                if (device.circulateFan) {
                    Text("Amount: ${device.circulateAmount}", modifier = Modifier.testTag("circulate-amount"))
                    DurationChips(device.circulateHoldDuration, { model.setDeviceCirculateHoldDuration(it) }, "circulate-run-for")
                }
            }
        }
    }
}

@Composable
private fun DurationChips(selected: HoldDuration, update: (HoldDuration) -> Unit, tag: String) {
    Column(Modifier.testTag(tag)) {
        Text("Run for")
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(HoldDuration.OneHour, HoldDuration.TwoHours, HoldDuration.Indefinite).forEach {
                FilterChip(selected == it, { update(it) }, { Text(it.label) })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SensorsSheet(model: AppModel, state: AppState, onDismiss: () -> Unit) {
    var detail by remember { mutableStateOf<RoomSensor?>(null) }
    ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.testTag("sensors-screen")) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Sensors", style = MaterialTheme.typography.headlineSmall)
            Text("Average ${state.device.currentTemp}° · ${state.device.humidity}% humidity")
            state.device.sensors.forEach { sensor ->
                ListItem(
                    headlineContent = { Text(sensor.name) },
                    supportingContent = { Text("${sensor.temp}° · ${sensor.humidity}%") },
                    trailingContent = {
                        Switch(
                            sensor.participating,
                            { model.toggleSensor(sensor.id, state.device.id) },
                            modifier = Modifier.testTag("sensor-participate-toggle-${sensor.name.lowercase()}"),
                        )
                    },
                    modifier = Modifier
                        .testTag("sensor-row-${sensor.name.lowercase()}")
                        .clickable { detail = sensor },
                )
            }
        }
    }
    detail?.let { sensor ->
        SensorDetailDialog(sensor, onDismiss = { detail = null }) {
            model.renameSensor(sensor.id, it, state.device.id)
            detail = null
        }
    }
}

@Composable
private fun SensorDetailDialog(sensor: RoomSensor, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    var name by remember(sensor.id) { mutableStateOf(sensor.name) }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Sensor details") },
        text = {
            Column {
                OutlinedTextField(name, { name = it }, label = { Text("Name") })
                Text("Battery: ${sensor.battery?.let { "$it%" } ?: "Wired"}")
            }
        },
        confirmButton = { androidx.compose.material3.TextButton(onClick = { onSave(name) }) { Text("Save") } },
        dismissButton = { androidx.compose.material3.TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
