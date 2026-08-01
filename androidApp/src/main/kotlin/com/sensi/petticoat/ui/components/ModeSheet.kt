package com.sensi.petticoat.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.model.Device
import com.sensi.petticoat.model.FanMode
import com.sensi.petticoat.model.HoldDuration
import com.sensi.petticoat.model.SystemMode

private val CIRCULATE_AMOUNTS = listOf("17% (10min)", "33% (15min)", "50% (30min)", "67% (40min)")

/**
 * Bottom sheet for choosing system mode, fan mode, and circulate settings for a device.
 * Port of iOS `ModeSheet.swift`. Custom multicolor mode art is deferred; labels only for now.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModeSheet(
    model: AppModel,
    device: Device,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text(
                "System",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )

            SectionHeader("System Mode")
            PillSegmentedSelector(
                options = SystemMode.entries.map { PillOption(it, it.label) },
                selected = device.systemMode,
                onSelect = { model.setSystemMode(it, device.id) },
            )

            SectionHeader("Fan")
            PillSegmentedSelector(
                options = FanMode.entries.map { PillOption(it, it.label) },
                selected = device.fanMode,
                onSelect = { model.setFanMode(it, device.id) },
            )

            if (device.fanMode == FanMode.On) {
                DurationRow(
                    title = "Run fan for",
                    selected = device.fanHoldDuration,
                    onSelect = { model.setDeviceFanHoldDuration(it, device.id) },
                )
            }

            SectionHeader("Circulate")
            SettingsCard {
                ToggleRow(
                    title = "Circulate Fan",
                    checked = device.circulateFan,
                    onCheckedChange = { model.setDeviceCirculateFan(it, device.id) },
                    subtitle = "Run the fan periodically to even out temperatures.",
                )
                if (device.circulateFan) {
                    RowDivider()
                    MenuRow(
                        title = "Amount",
                        current = device.circulateAmount,
                        options = CIRCULATE_AMOUNTS,
                        labelOf = { it },
                        onSelect = { model.setDeviceCirculateAmount(it, device.id) },
                    )
                    RowDivider()
                    MenuRow(
                        title = "Run for",
                        current = device.circulateHoldDuration,
                        options = HoldDuration.entries,
                        labelOf = { it.label },
                        onSelect = { model.setDeviceCirculateHoldDuration(it, device.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun DurationRow(
    title: String,
    selected: HoldDuration,
    onSelect: (HoldDuration) -> Unit,
) {
    SettingsCard {
        MenuRow(
            title = title,
            current = selected,
            options = HoldDuration.entries,
            labelOf = { it.label },
            onSelect = onSelect,
        )
    }
}

/** A row with a trailing dropdown menu over [options]. */
@Composable
fun <T> MenuRow(
    title: String,
    current: T,
    options: List<T>,
    labelOf: (T) -> String,
    onSelect: (T) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = { expanded = true }) {
            Text(labelOf(current))
            Spacer(Modifier.height(0.dp))
            Icon(Icons.Outlined.KeyboardArrowDown, contentDescription = null)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(labelOf(option)) },
                    onClick = {
                        onSelect(option)
                        expanded = false
                    },
                )
            }
        }
    }
}
