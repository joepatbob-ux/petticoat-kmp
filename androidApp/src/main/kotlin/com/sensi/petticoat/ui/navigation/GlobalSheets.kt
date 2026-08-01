package com.sensi.petticoat.ui.navigation

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.InstallCatalog
import com.sensi.petticoat.model.InstallDevice
import com.sensi.petticoat.model.InstallStepKind
import com.sensi.petticoat.model.WireConfigValidator

@Composable
fun GlobalSheets(model: AppModel, state: AppState) {
    if (state.showAccount) AccountSheet(model) { model.setShowAccount(false) }
    if (state.showHelp) HelpSheet { model.setShowHelp(false) }
    if (state.showAddDevice) AddDeviceSheet(model) { model.setShowAddDevice(false) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AccountSheet(model: AppModel, onDismiss: () -> Unit) {
    var confirmLogout by remember { mutableStateOf(false) }
    ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.testTag("account-sheet")) {
        Column(Modifier.padding(20.dp)) {
            Text("Account", style = MaterialTheme.typography.headlineSmall)
            listOf("Personal information", "Homes", "Application settings", "Notifications", "Energy", "About").forEach {
                ListItem(
                    headlineContent = { Text(it) },
                    trailingContent = { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, null) },
                )
            }
            ListItem(
                headlineContent = { Text("Help & Support") },
                modifier = Modifier.clickable { onDismiss(); model.setShowHelp(true) },
            )
            TextButton(onClick = { confirmLogout = true }, modifier = Modifier.testTag("account-logout")) {
                Text("Log out")
            }
        }
    }
    if (confirmLogout) {
        AlertDialog(
            onDismissRequest = { confirmLogout = false },
            title = { Text("Log out?") },
            confirmButton = {
                TextButton(onClick = { confirmLogout = false; onDismiss(); model.signOut() }) { Text("Log out") }
            },
            dismissButton = { TextButton(onClick = { confirmLogout = false }) { Text("Cancel") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HelpSheet(onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.testTag("help-screen")) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Text("Help & Support", style = MaterialTheme.typography.headlineSmall)
            AndroidView(
                factory = { context ->
                    WebView(context).apply {
                        webViewClient = WebViewClient()
                        settings.javaScriptEnabled = true
                        loadUrl("https://help.sensi.copeland.com/")
                    }
                },
                modifier = Modifier.fillMaxWidth().height(520.dp),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddDeviceSheet(model: AppModel, onDismiss: () -> Unit) {
    var selected by remember { mutableStateOf<InstallDevice?>(null) }
    var step by remember { mutableStateOf(0) }
    var wires by remember { mutableStateOf<Set<String>>(emptySet()) }
    ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.testTag("add-device-sheet")) {
        if (selected == null) {
            Column(Modifier.padding(20.dp)) {
                Text("Add Device", style = MaterialTheme.typography.headlineSmall)
                InstallCatalog.devices.forEach { device ->
                    ListItem(
                        headlineContent = { Text(device.name) },
                        supportingContent = { Text(device.subtitle) },
                        trailingContent = { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, null) },
                        modifier = Modifier.clickable { selected = device; step = 0 },
                    )
                }
            }
        } else {
            val device = selected!!
            val current = device.steps[step]
            Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("${current.stage} · Step ${step + 1} of ${device.steps.size}", modifier = Modifier.testTag("install-progress"))
                Text(current.title, style = MaterialTheme.typography.headlineSmall)
                Text(current.body)
                if (current.kind == InstallStepKind.WirePicker) {
                    val allowed = WireConfigValidator.allowed(wires)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        WireConfigValidator.terminalOrder.take(7).forEach { terminal ->
                            OutlinedButton(
                                enabled = terminal in allowed || terminal in wires,
                                onClick = { wires = if (terminal in wires) wires - terminal else wires + terminal },
                                modifier = Modifier.testTag("wire-terminal-$terminal"),
                            ) { Text(terminal) }
                        }
                    }
                }
                Button(
                    enabled = current.kind != InstallStepKind.WirePicker || WireConfigValidator.isValid(wires),
                    onClick = {
                        if (step == device.steps.lastIndex) {
                            model.addDevice(if (device.isRoomSensor) "Room Sensor" else device.name)
                            onDismiss()
                        } else step++
                    },
                    modifier = Modifier.fillMaxWidth().testTag(if (device.isRoomSensor) "room-sensor-complete" else "install-continue"),
                ) { Text(if (step == device.steps.lastIndex) "Complete" else "Continue") }
                TextButton(onClick = { if (step > 0) step-- else selected = null }) { Text("Back") }
            }
        }
    }
}
