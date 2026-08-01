package com.sensi.petticoat.ui.screens

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.ControlMode
import com.sensi.petticoat.model.HVACActivity
import com.sensi.petticoat.model.SetpointBound
import com.sensi.petticoat.model.SystemMode
import com.sensi.petticoat.ui.theme.SensiControlFill
import com.sensi.petticoat.ui.theme.SensiCooling
import com.sensi.petticoat.ui.theme.SensiHeating
import com.sensi.petticoat.ui.theme.SensiThermostatSurface

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun ControlScreen(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    val device = state.device
    val activityColor = when (device.activity) {
        HVACActivity.Heating -> SensiHeating
        HVACActivity.Cooling -> SensiCooling
        HVACActivity.Idle -> Color(0xFF8E8E93)
    }
    val pulse by animateFloatAsState(
        targetValue = if (device.activity == HVACActivity.Idle) 1f else 1.04f,
        animationSpec = spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessLow),
        label = "tempPulse",
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(device.name, fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = SensiThermostatSurface,
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White,
                ),
            )
        },
        containerColor = SensiThermostatSurface,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(12.dp))
            Text(
                device.systemMode.setpointLabel,
                color = Color.White.copy(alpha = 0.7f),
                style = MaterialTheme.typography.labelLarge,
            )
            Spacer(Modifier.height(8.dp))

            Text(
                text = if (device.systemMode.isRangeSetpoint) {
                    "${device.keepMin}–${device.keepMax}"
                } else if (device.systemMode == SystemMode.Cool) {
                    "${device.keepMax}"
                } else {
                    "${device.keepMin}"
                },
                fontSize = 64.sp,
                fontWeight = FontWeight.Light,
                color = Color.White,
                modifier = Modifier.scale(pulse),
            )

            Text(
                "${device.currentTemp}° now · ${device.humidity}%",
                color = activityColor,
                style = MaterialTheme.typography.titleMedium,
            )

            Spacer(Modifier.height(28.dp))

            Row(
                horizontalArrangement = Arrangement.spacedBy(28.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SetpointButton(Icons.Outlined.Remove, "Decrease") {
                    when (device.systemMode) {
                        SystemMode.Cool -> model.adjustKeep(SetpointBound.High, -1)
                        SystemMode.Heat, SystemMode.AuxHeat -> model.adjustKeep(SetpointBound.Low, -1)
                        else -> {
                            model.adjustKeep(SetpointBound.Low, -1)
                            model.adjustKeep(SetpointBound.High, -1)
                        }
                    }
                }
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(activityColor),
                )
                SetpointButton(Icons.Outlined.Add, "Increase") {
                    when (device.systemMode) {
                        SystemMode.Cool -> model.adjustKeep(SetpointBound.High, 1)
                        SystemMode.Heat, SystemMode.AuxHeat -> model.adjustKeep(SetpointBound.Low, 1)
                        else -> {
                            model.adjustKeep(SetpointBound.Low, 1)
                            model.adjustKeep(SetpointBound.High, 1)
                        }
                    }
                }
            }

            Spacer(Modifier.height(32.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SystemMode.entries.forEach { mode ->
                    FilterChip(
                        selected = device.systemMode == mode,
                        onClick = { model.setSystemMode(mode) },
                        label = { Text(mode.label) },
                        colors = FilterChipDefaults.filterChipColors(
                            containerColor = SensiControlFill,
                            labelColor = Color.White.copy(alpha = 0.8f),
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = Color.White,
                        ),
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(SensiControlFill)
                    .padding(16.dp),
            ) {
                Text(
                    when (state.controlMode) {
                        ControlMode.Schedule -> "Following ${state.scheduleName}"
                        ControlMode.Hold -> "Hold until ${state.holdUntilText}"
                        ControlMode.Activity -> "Activity · ${state.activeProfile.name}"
                        ControlMode.Vacation -> "Vacation"
                        ControlMode.Standard -> "Manual"
                    },
                    color = Color.White,
                    style = MaterialTheme.typography.titleSmall,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    state.currentPeriod()?.let { "Now: ${it.name} · ${it.startText}" }
                        ?: "No schedule period",
                    color = Color.White.copy(alpha = 0.65f),
                    style = MaterialTheme.typography.bodySmall,
                )
                if (state.controlMode == ControlMode.Hold) {
                    TextButton(onClick = model::resumeSchedule) {
                        Text("Resume schedule")
                    }
                }
            }
        }
    }
}

@Composable
private fun SetpointButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(64.dp)
            .clip(CircleShape)
            .background(SensiControlFill),
        colors = IconButtonDefaults.iconButtonColors(contentColor = Color.White),
    ) {
        Icon(icon, contentDescription = label, modifier = Modifier.size(28.dp))
    }
}
