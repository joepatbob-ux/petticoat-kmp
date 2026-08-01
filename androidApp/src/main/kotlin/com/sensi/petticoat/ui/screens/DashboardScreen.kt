package com.sensi.petticoat.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.WifiOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.Device
import com.sensi.petticoat.model.HVACActivity
import com.sensi.petticoat.model.SpotlightItem
import com.sensi.petticoat.model.SpotlightKind
import com.sensi.petticoat.ui.theme.SensiCooling
import com.sensi.petticoat.ui.theme.SensiHeating
import com.sensi.petticoat.ui.theme.SensiThermostatSurface
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun DashboardScreen(
    model: AppModel,
    state: AppState,
    onOpenDevice: (String) -> Unit,
) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(40)
        visible = true
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "sensi",
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-0.5).sp,
                    )
                },
                actions = {
                    IconButton(onClick = { model.setShowAccount(true) }) {
                        Icon(Icons.Outlined.AccountCircle, contentDescription = "Account")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { model.setShowAddDevice(true) },
                containerColor = MaterialTheme.colorScheme.primary,
            ) {
                Icon(Icons.Outlined.Add, contentDescription = "Add device")
            }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn() + slideInVertically { it / 8 },
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                item {
                    Text(
                        "Thermostats",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                itemsIndexed(state.devices, key = { _, d -> d.id }) { _, device ->
                    ThermostatCard(device = device, onClick = { onOpenDevice(device.id) })
                }
                if (state.visibleSpotlights.isNotEmpty()) {
                    item {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Spotlight",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    itemsIndexed(state.visibleSpotlights, key = { _, s -> s.id }) { _, item ->
                        SpotlightCard(item)
                    }
                }
            }
        }
    }
}

@Composable
private fun ThermostatCard(device: Device, onClick: () -> Unit) {
    val activityColor = when (device.activity) {
        HVACActivity.Heating -> SensiHeating
        HVACActivity.Cooling -> SensiCooling
        HVACActivity.Idle -> Color(0xFF8E8E93)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("thermostat-${device.name.lowercase()}")
            .clip(RoundedCornerShape(28.dp))
            .background(SensiThermostatSurface)
            .clickable(onClick = onClick)
            .padding(20.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    device.name,
                    style = MaterialTheme.typography.titleLarge,
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    device.location,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f),
                )
            }
            if (device.isOffline) {
                Icon(
                    Icons.Outlined.WifiOff,
                    contentDescription = "Offline",
                    tint = Color(0xFFE0392B),
                    modifier = Modifier.size(28.dp),
                )
            }
        }
        Spacer(Modifier.height(20.dp))
        if (device.isOffline) {
            Text(
                "Offline since ${device.offlineSince.orEmpty()}",
                color = Color.White.copy(alpha = 0.85f),
                style = MaterialTheme.typography.bodyMedium,
            )
        } else {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    "${device.currentTemp}°",
                    fontSize = 56.sp,
                    fontWeight = FontWeight.Light,
                    color = activityColor,
                )
                Spacer(Modifier.size(12.dp))
                Column(modifier = Modifier.padding(bottom = 10.dp)) {
                    Text(
                        "${device.keepMin}–${device.keepMax}°",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(
                        device.systemMode.label,
                        color = Color.White.copy(alpha = 0.7f),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                device.sensorSummary,
                color = Color.White.copy(alpha = 0.65f),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun SpotlightCard(item: SpotlightItem) {
    val filled = item.kind == SpotlightKind.Promotional
    val bg = if (filled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface
    val fg = if (filled) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(bg)
            .padding(20.dp),
    ) {
        if (item.provider.isNotEmpty()) {
            Text(
                item.provider,
                style = MaterialTheme.typography.labelMedium,
                color = fg.copy(alpha = 0.7f),
            )
            Spacer(Modifier.height(4.dp))
        }
        Text(item.title, style = MaterialTheme.typography.titleMedium, color = fg, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(6.dp))
        Text(item.body, style = MaterialTheme.typography.bodyMedium, color = fg.copy(alpha = 0.85f))
        if (item.subline.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text(item.subline, style = MaterialTheme.typography.bodySmall, color = fg.copy(alpha = 0.6f))
        }
    }
}
