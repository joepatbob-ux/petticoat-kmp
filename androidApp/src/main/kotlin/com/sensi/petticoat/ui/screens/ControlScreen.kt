package com.sensi.petticoat.ui.screens

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.AcUnit
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Cyclone
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material.icons.outlined.Thunderstorm
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.Device
import com.sensi.petticoat.model.FanMode
import com.sensi.petticoat.model.HVACActivity
import com.sensi.petticoat.model.SetpointBound
import com.sensi.petticoat.ui.components.ModeSheet
import com.sensi.petticoat.ui.components.iconForSymbol
import com.sensi.petticoat.ui.theme.SensiCooling
import com.sensi.petticoat.ui.theme.SensiFanPurple
import com.sensi.petticoat.ui.theme.SensiHeating

/**
 * Control tab, built to the Android Expressive Figma ("Enviromental Control", 318:56879):
 * centered app bar, weather row, "Average of N Sensors" pill, large current temperature with
 * humidity stat, a cool/fan mode-select pill, and a bottom activity/setpoint card. The bottom
 * navigation bar is supplied by [DeviceDetailScreen].
 *
 * Note: custom Figma glyphs (thunderstorm/cool/fan/water-drop/air) are rendered with the
 * closest Material icons pending an exported-asset pipeline.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun ControlContent(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
    onOpenSensors: () -> Unit,
) {
    val device = state.device
    var showModeSheet by remember { mutableStateOf(false) }
    var selectedBound by remember { mutableStateOf(SetpointBound.High) }

    val pulse by animateFloatAsState(
        targetValue = if (device.activity == HVACActivity.Idle) 1f else 1.03f,
        animationSpec = spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessLow),
        label = "tempPulse",
    )

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(device.name, fontWeight = FontWeight.Medium) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { model.setShowAccount(true) }) {
                        Icon(Icons.Outlined.AccountCircle, contentDescription = "Account")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
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
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(8.dp))
            WeatherRow(device)

            Spacer(Modifier.height(24.dp))
            SensorsPill(count = device.participatingCount, onClick = onOpenSensors)

            Spacer(Modifier.height(8.dp))
            Text(
                "${device.currentTemp}",
                fontSize = 96.sp,
                fontWeight = FontWeight.Normal,
                letterSpacing = (-0.25).sp,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.scale(pulse),
            )
            StatsRow(device)

            Spacer(Modifier.height(16.dp))
            ModeSelectPill(device = device, onClick = { showModeSheet = true })

            Spacer(Modifier.weight(1f))

            ActivityCard(
                state = state,
                device = device,
                selectedBound = selectedBound,
                onSelectBound = { selectedBound = it },
                onAdjust = { delta -> model.adjustKeep(selectedBound, delta) },
            )
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showModeSheet) {
        ModeSheet(model = model, device = device, onDismiss = { showModeSheet = false })
    }
}

@Composable
private fun WeatherRow(device: Device) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            device.location,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(4.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Outlined.Thunderstorm,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(30.dp),
            )
            Text(
                "${device.outdoorTemp}",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Column {
                Text(
                    "H: ${device.outdoorHigh}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "L: ${device.outdoorLow}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SensorsPill(count: Int, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(100.dp))
            .background(MaterialTheme.colorScheme.secondaryContainer)
            .clickable(onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "Average of",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.5f),
        )
        Text(
            "$count Sensors",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSecondaryContainer,
        )
    }
}

@Composable
private fun StatsRow(device: Device) {
    // Figma shows a second "air" stat; the model has no matching field, so only humidity
    // (which the model provides) is shown until a data source exists.
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Stat(Icons.Outlined.WaterDrop, "${device.humidity}%", SensiCooling)
    }
}

@Composable
private fun Stat(icon: ImageVector, value: String, tint: androidx.compose.ui.graphics.Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
        Text(
            value,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ModeSelectPill(device: Device, onClick: () -> Unit) {
    val modeIcon = iconForSystemMode(device)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(66.dp))
            .background(MaterialTheme.colorScheme.secondaryContainer)
            .clickable(onClick = onClick)
            .padding(11.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(modeIcon.first, contentDescription = "System mode", tint = modeIcon.second, modifier = Modifier.size(28.dp))
        if (device.fanMode == FanMode.On) {
            Icon(Icons.Outlined.Cyclone, contentDescription = "Fan", tint = SensiFanPurple, modifier = Modifier.size(28.dp))
        }
    }
}

@Composable
private fun ActivityCard(
    state: AppState,
    device: Device,
    selectedBound: SetpointBound,
    onSelectBound: (SetpointBound) -> Unit,
    onAdjust: (Int) -> Unit,
) {
    val title = when (state.controlMode) {
        ControlMode.Activity -> state.activeProfile.name
        ControlMode.Vacation -> "Vacation"
        else -> state.currentPeriod()?.name ?: state.scheduleName
    }
    val symbol = if (state.controlMode == ControlMode.Activity) state.activeProfile.symbol else "dumbbell.fill"

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(100.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                iconForSymbol(symbol),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(24.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            SetpointSwitcher(
                low = device.keepMin,
                high = device.keepMax,
                selected = selectedBound,
                onSelect = onSelectBound,
            )
            Spacer(Modifier.width(8.dp))
            Column {
                IconButton(onClick = { onAdjust(1) }, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Outlined.Add, contentDescription = "Increase")
                }
                IconButton(onClick = { onAdjust(-1) }, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Outlined.Remove, contentDescription = "Decrease")
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            "Now until ${device.holdUntil}",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SetpointSwitcher(
    low: Int,
    high: Int,
    selected: SetpointBound,
    onSelect: (SetpointBound) -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(64.dp))
            .background(MaterialTheme.colorScheme.secondaryContainer),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SetpointChip(
            value = low,
            selected = selected == SetpointBound.Low,
            onClick = { onSelect(SetpointBound.Low) },
        )
        SetpointChip(
            value = high,
            selected = selected == SetpointBound.High,
            onClick = { onSelect(SetpointBound.High) },
        )
    }
}

@Composable
private fun SetpointChip(value: Int, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(
                if (selected) MaterialTheme.colorScheme.primary
                else androidx.compose.ui.graphics.Color.Transparent,
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "$value",
            style = MaterialTheme.typography.bodyLarge,
            color = if (selected) MaterialTheme.colorScheme.onPrimary
            else MaterialTheme.colorScheme.onSecondaryContainer,
        )
    }
}

/** Maps the device's system mode to a Material glyph + tint (custom Figma art deferred). */
@Composable
private fun iconForSystemMode(device: Device): Pair<ImageVector, androidx.compose.ui.graphics.Color> =
    when (device.activity) {
        HVACActivity.Heating -> Icons.Outlined.Thunderstorm to SensiHeating
        HVACActivity.Cooling -> Icons.Outlined.AcUnit to SensiCooling
        HVACActivity.Idle -> Icons.Outlined.AcUnit to SensiCooling
    }
