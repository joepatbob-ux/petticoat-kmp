package com.sensi.petticoat.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.dp

/**
 * Minute-of-day picker dialog (12-hour with AM/PM, 15-minute increments). Replaces the iOS
 * `UIDatePicker`-based `IntervalTimePicker`. [initialMinutes] and the confirmed value are
 * minutes since midnight (0..<1440).
 */
@Composable
fun TimePickerDialog(
    initialMinutes: Int,
    onConfirm: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val snapped = (initialMinutes / 15) * 15
    val initHour24 = snapped / 60
    var hour12 by remember { mutableIntStateOf(((initHour24 + 11) % 12) + 1) }
    var minute by remember { mutableIntStateOf(snapped % 60) }
    var isPm by remember { mutableStateOf(initHour24 >= 12) }

    fun composeMinutes(): Int {
        val base = (hour12 % 12) + if (isPm) 12 else 0
        return base * 60 + minute
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Start Time") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                MenuRow(
                    title = "Hour",
                    current = hour12,
                    options = (1..12).toList(),
                    labelOf = { it.toString() },
                    onSelect = { hour12 = it },
                )
                MenuRow(
                    title = "Minute",
                    current = minute,
                    options = listOf(0, 15, 30, 45),
                    labelOf = { it.toString().padStart(2, '0') },
                    onSelect = { minute = it },
                )
                MenuRow(
                    title = "AM / PM",
                    current = if (isPm) "PM" else "AM",
                    options = listOf("AM", "PM"),
                    labelOf = { it },
                    onSelect = { isPm = it == "PM" },
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(composeMinutes()) }) { Text("Set") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}
