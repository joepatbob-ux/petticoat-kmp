package com.sensi.petticoat.ui.screens.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.Contractor
import com.sensi.petticoat.model.TemperatureUnit
import com.sensi.petticoat.model.ThermostatSettings
import com.sensi.petticoat.model.ThermostatSettingsConfig

private enum class SettingsPage(val title: String) {
    Root("Settings"),
    Display("Display options"),
    System("System configuration"),
    About("About thermostat"),
    Location("Thermostat location"),
    Contractor("Contractor information"),
    Energy("Energy programs"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(model: AppModel, state: AppState, onBack: () -> Unit) {
    var page by remember { mutableStateOf(SettingsPage.Root) }
    val back = { if (page == SettingsPage.Root) onBack() else page = SettingsPage.Root }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(page.title) },
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            when (page) {
                SettingsPage.Root -> SettingsRoot { page = it }
                SettingsPage.Display -> DisplayOptions(state.thermostatSettings, model::setThermostatSettings)
                SettingsPage.System -> SystemConfiguration(state.thermostatSettings, model::setThermostatSettings)
                SettingsPage.About -> AboutThermostat(state.thermostatSettings) {
                    page = SettingsPage.Location
                }
                SettingsPage.Location -> LocationSettings(state.thermostatSettings, model::setThermostatSettings)
                SettingsPage.Contractor -> ContractorSettings(state.contractor, model::setContractor)
                SettingsPage.Energy -> EnergyPrograms()
            }
        }
    }
}

@Composable
private fun SettingsRoot(open: (SettingsPage) -> Unit) {
    LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { SettingsGroup(listOf(SettingsPage.Display, SettingsPage.System), open) }
        item { SettingsGroup(listOf(SettingsPage.About, SettingsPage.Contractor), open) }
        item { SettingsGroup(listOf(SettingsPage.Energy), open) }
    }
}

@Composable
private fun SettingsGroup(pages: List<SettingsPage>, open: (SettingsPage) -> Unit) {
    Card {
        pages.forEach { page ->
            ListItem(
                headlineContent = { Text(page.title) },
                trailingContent = { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, null) },
                modifier = Modifier.clickable { open(page) },
            )
        }
    }
}

@Composable
private fun DisplayOptions(settings: ThermostatSettings, update: (ThermostatSettings) -> Unit) {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { SwitchRow("Continuous backlight", settings.continuousBacklight) { update(settings.copy(continuousBacklight = it)) } }
        item { SwitchRow("Display humidity", settings.displayHumidity) { update(settings.copy(displayHumidity = it)) } }
        item { SwitchRow("Display time", settings.displayTime) { update(settings.copy(displayTime = it)) } }
        item {
            Card {
                ListItem(
                    headlineContent = { Text("Temperature units") },
                    supportingContent = { Text(settings.units.label) },
                    trailingContent = {
                        Row {
                            TemperatureUnit.entries.forEach { unit ->
                                TextButton(onClick = { update(settings.copy(units = unit)) }) {
                                    Text(unit.label)
                                }
                            }
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun SystemConfiguration(settings: ThermostatSettings, update: (ThermostatSettings) -> Unit) {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { SwitchRow("Lock thermostat", settings.lockThermostat) { update(settings.copy(lockThermostat = it)) } }
        item { SwitchRow("Humidification", settings.humidification) { update(settings.copy(humidification = it)) } }
        item { SwitchRow("Dehumidification", settings.dehumidification) { update(settings.copy(dehumidification = it)) } }
        item { SwitchRow("AC protection", settings.acProtection) { update(settings.copy(acProtection = it)) } }
        item {
            SettingValueRow("Cooling minimum", "${settings.coolingMin}°") {
                val next = settings.coolingMin + 1
                update(settings.copy(coolingMin = if (next > ThermostatSettingsConfig.coolingMinRange.last) ThermostatSettingsConfig.coolingMinRange.first else next))
            }
        }
        item {
            SettingValueRow("Heating maximum", "${settings.heatingMax}°") {
                val next = settings.heatingMax + 1
                update(settings.copy(heatingMax = if (next > ThermostatSettingsConfig.heatingMaxRange.last) ThermostatSettingsConfig.heatingMaxRange.first else next))
            }
        }
        item {
            Text(
                "Boost: ${settings.coolingBoost} · ${settings.heatingBoost} · ${settings.auxBoost}",
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun AboutThermostat(settings: ThermostatSettings, openLocation: () -> Unit) {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { SettingValueRow("Thermostat name", settings.name.ifBlank { "Home" }) {} }
        item { SettingValueRow("Location", settings.locationCity.ifBlank { "St. Louis, MO" }, openLocation) }
        item { SettingValueRow("Model", "1F86U-42WF") {} }
        item { SettingValueRow("Firmware", "6004971003") {} }
        item { SettingValueRow("Wi‑Fi strength", "Excellent") {} }
    }
}

@Composable
private fun LocationSettings(settings: ThermostatSettings, update: (ThermostatSettings) -> Unit) {
    var draft by remember(settings) { mutableStateOf(settings) }
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedTextField(draft.locationAddress, { draft = draft.copy(locationAddress = it) }, label = { Text("Address") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(draft.locationCity, { draft = draft.copy(locationCity = it) }, label = { Text("City") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(draft.locationState, { draft = draft.copy(locationState = it) }, label = { Text("State") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(draft.locationZip, { draft = draft.copy(locationZip = it) }, label = { Text("ZIP code") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = { update(draft) }, modifier = Modifier.fillMaxWidth()) { Text("Save location") }
    }
}

@Composable
private fun ContractorSettings(contractor: Contractor, update: (Contractor) -> Unit) {
    var draft by remember(contractor) { mutableStateOf(contractor) }
    var confirmRemove by remember { mutableStateOf(false) }
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedTextField(draft.company, { draft = draft.copy(company = it) }, label = { Text("Company") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(draft.phone, { draft = draft.copy(phone = it) }, label = { Text("Phone") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(draft.address, { draft = draft.copy(address = it) }, label = { Text("Address") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = { update(draft) }, modifier = Modifier.fillMaxWidth()) { Text("Save contractor") }
        OutlinedButton(onClick = { confirmRemove = true }, modifier = Modifier.fillMaxWidth()) {
            Text("Remove contractor")
        }
    }
    if (confirmRemove) {
        AlertDialog(
            onDismissRequest = { confirmRemove = false },
            title = { Text("Remove contractor?") },
            confirmButton = {
                TextButton(onClick = { update(Contractor()); confirmRemove = false }) { Text("Remove") }
            },
            dismissButton = { TextButton(onClick = { confirmRemove = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun EnergyPrograms() {
    LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("EcoSmart", style = MaterialTheme.typography.titleMedium)
                    Text("Save energy during peak demand events.")
                    Button(onClick = {}) { Text("Enroll") }
                }
            }
        }
    }
}

@Composable
private fun SwitchRow(title: String, checked: Boolean, onChecked: (Boolean) -> Unit) {
    Card {
        ListItem(
            headlineContent = { Text(title) },
            trailingContent = { Switch(checked, onChecked) },
        )
    }
}

@Composable
private fun SettingValueRow(title: String, value: String, onClick: () -> Unit) {
    Card(onClick = onClick) {
        ListItem(
            headlineContent = { Text(title) },
            supportingContent = { Text(value) },
            trailingContent = { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, null) },
        )
    }
}
