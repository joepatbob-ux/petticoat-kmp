package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.BatteryFull
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.Device
import com.sensi.petticoat.model.RoomSensor
import com.sensi.petticoat.ui.components.SectionHeader
import com.sensi.petticoat.ui.components.SettingsCard
import com.sensi.petticoat.ui.components.RowDivider

/**
 * Sensors screen (opened from the Control sensor pill) and Sensor Details.
 * Port of iOS `SensorsView.swift`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SensorsScreen(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    val device = state.device
    var detailSensorId by remember { mutableStateOf<String?>(null) }
    val detailSensor = device.sensors.firstOrNull { it.id == detailSensorId }

    if (detailSensor != null) {
        SensorDetail(
            sensor = detailSensor,
            unitLabel = state.thermostatSettings.units.label,
            onRename = { model.renameSensor(detailSensor.id, it, device.id) },
            onBack = { detailSensorId = null },
        )
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Sensors") },
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
            ReadoutTiles(device)

            val thermostatSensors = device.sensors.filter { it.battery == null }
            val roomSensors = device.sensors.filter { it.battery != null }

            if (thermostatSensors.isNotEmpty()) {
                SectionHeader("Thermostat")
                SettingsCard {
                    thermostatSensors.forEachIndexed { index, sensor ->
                        if (index > 0) RowDivider()
                        SensorRow(
                            sensor = sensor,
                            canOpenDetail = false,
                            onToggle = { model.toggleSensor(sensor.id, device.id) },
                            onOpen = {},
                        )
                    }
                }
            }

            if (roomSensors.isNotEmpty()) {
                SectionHeader("Sensors")
                SettingsCard {
                    roomSensors.forEachIndexed { index, sensor ->
                        if (index > 0) RowDivider()
                        SensorRow(
                            sensor = sensor,
                            canOpenDetail = true,
                            onToggle = { model.toggleSensor(sensor.id, device.id) },
                            onOpen = { detailSensorId = sensor.id },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ReadoutTiles(device: Device) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        ReadoutTile("Temperature", "${device.currentTemp}°", Modifier.weight(1f))
        ReadoutTile("Humidity", "${device.humidity}%", Modifier.weight(1f))
    }
}

@Composable
private fun ReadoutTile(title: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(20.dp),
    ) {
        Text(
            title,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            value,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Light,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun SensorRow(
    sensor: RoomSensor,
    canOpenDetail: Boolean,
    onToggle: () -> Unit,
    onOpen: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onToggle) {
            if (sensor.participating) {
                Icon(
                    Icons.Outlined.CheckCircle,
                    contentDescription = "Participating",
                    tint = MaterialTheme.colorScheme.primary,
                )
            } else {
                Icon(
                    Icons.Outlined.RadioButtonUnchecked,
                    contentDescription = "Not participating",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                sensor.name,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                "${sensor.temp}° · ${sensor.humidity}%",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        val battery = sensor.battery
        if (battery != null) {
            Icon(
                Icons.Outlined.BatteryFull,
                contentDescription = "Battery",
                tint = batteryColor(battery),
                modifier = Modifier.size(20.dp),
            )
            Text(
                "$battery%",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (canOpenDetail) {
            IconButton(onClick = onOpen) {
                Icon(
                    Icons.Outlined.KeyboardArrowRight,
                    contentDescription = "Details",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SensorDetail(
    sensor: RoomSensor,
    unitLabel: String,
    onRename: (String) -> Unit,
    onBack: () -> Unit,
) {
    var name by remember(sensor.id) { mutableStateOf(sensor.name) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Sensor Details") },
                navigationIcon = {
                    IconButton(onClick = {
                        onRename(name)
                        onBack()
                    }) {
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            SettingsCard {
                InfoRow("Temperature", "${sensor.temp}$unitLabel")
                RowDivider()
                InfoRow("Humidity", "${sensor.humidity}%")
                val battery = sensor.battery
                if (battery != null) {
                    RowDivider()
                    InfoRow("Battery", "$battery%")
                    RowDivider()
                    InfoRow("Battery Health", batteryHealth(battery))
                }
            }
        }
    }
}

@Composable
private fun InfoRow(title: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun batteryColor(level: Int): Color = when {
    level < 20 -> Color(0xFFE0392B)
    level < 50 -> Color(0xFFF6A609)
    else -> Color(0xFF34C759)
}

private fun batteryHealth(level: Int): String = when {
    level < 20 -> "Replace soon"
    level < 50 -> "Fair"
    else -> "Good"
}
