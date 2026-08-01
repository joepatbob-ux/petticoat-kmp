package com.sensi.petticoat.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/** Monday-first day labels; index 0 = Monday … 6 = Sunday (matches shared weekday indexing). */
private val DAY_LABELS = listOf("M", "T", "W", "T", "F", "S", "S")

/**
 * Seven-day multi-select row used by schedule/program editors.
 * Port of the iOS `DayPicker` (ScheduleComponents.swift), simplified to a two-state toggle
 * (in-group / not) — the tri-state "used elsewhere" affordance is deferred.
 */
@Composable
fun DayPicker(
    selected: Set<Int>,
    onToggle: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        DAY_LABELS.forEachIndexed { index, label ->
            val isOn = index in selected
            val bg by animateColorAsState(
                targetValue = if (isOn) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.surfaceVariant,
                label = "dayBg",
            )
            val fg = if (isOn) MaterialTheme.colorScheme.onPrimary
            else MaterialTheme.colorScheme.onSurfaceVariant
            Box(
                modifier = Modifier
                    .weight(1f)
                    .aspectRatio(1f)
                    .clip(CircleShape)
                    .background(bg)
                    .clickable { onToggle(index) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label,
                    style = MaterialTheme.typography.labelLarge,
                    color = fg,
                    fontWeight = if (isOn) FontWeight.Bold else FontWeight.Normal,
                )
            }
        }
    }
}
