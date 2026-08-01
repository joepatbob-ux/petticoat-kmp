package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.Contractor
import com.sensi.petticoat.model.TemperatureUnit
import com.sensi.petticoat.model.ThermostatSettings
import com.sensi.petticoat.ui.components.MenuRow
import com.sensi.petticoat.ui.components.RowDivider
import com.sensi.petticoat.ui.components.SectionHeader
import com.sensi.petticoat.ui.components.SettingsCard
import com.sensi.petticoat.ui.components.StepperRow
import com.sensi.petticoat.ui.components.ToggleRow

private enum class SettingsRoute { Menu, Display, System, About, Location, Contractor, Energy }

private val BOOST_OPTIONS = listOf("Comfort", "Balanced", "Efficiency", "Max")

/**
 * Settings tab: a menu plus Display Options, System Configuration, About, Location,
 * Contractor, and Energy Programs subscreens. Port of iOS `SettingsFlow.swift`.
 * Sub-navigation is local state; drilling in shows that subscreen with a back arrow.
 */
@Composable
fun SettingsScreen(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    var route by remember { mutableStateOf(SettingsRoute.Menu) }

    when (route) {
        SettingsRoute.Menu -> SettingsMenu(state, onBack) { route = it }
        SettingsRoute.Display -> DisplayOptions(model, state) { route = SettingsRoute.Menu }
        SettingsRoute.System -> SystemConfiguration(model, state) { route = SettingsRoute.Menu }
        SettingsRoute.About -> AboutThermostat(state) { route = SettingsRoute.Menu }
        SettingsRoute.Location -> LocationForm(model, state) { route = SettingsRoute.Menu }
        SettingsRoute.Contractor -> ContractorForm(model, state) { route = SettingsRoute.Menu }
        SettingsRoute.Energy -> EnergyPrograms { route = SettingsRoute.Menu }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SubScaffold(
    title: String,
    onBack: () -> Unit,
    content: @Composable (Modifier) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
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
        content(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        )
    }
}

@Composable
private fun SettingsMenu(
    state: AppState,
    onBack: () -> Unit,
    onNavigate: (SettingsRoute) -> Unit,
) {
    SubScaffold(title = "${state.device.name} Settings", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SettingsCard {
                NavRow("Display Options") { onNavigate(SettingsRoute.Display) }
                RowDivider()
                NavRow("System Configuration") { onNavigate(SettingsRoute.System) }
                RowDivider()
                NavRow("About Thermostat") { onNavigate(SettingsRoute.About) }
            }
            SettingsCard {
                NavRow("Thermostat Location") { onNavigate(SettingsRoute.Location) }
                RowDivider()
                NavRow("Contractor Information") { onNavigate(SettingsRoute.Contractor) }
                RowDivider()
                NavRow("Energy Programs") { onNavigate(SettingsRoute.Energy) }
            }
        }
    }
}

// Local nav-row wrapper so the menu reads cleanly; delegates to the shared NavRow.
@Composable
private fun NavRow(title: String, onClick: () -> Unit) =
    com.sensi.petticoat.ui.components.NavRow(title = title, onClick = onClick)

@Composable
private fun DisplayOptions(model: AppModel, state: AppState, onBack: () -> Unit) {
    val s = state.thermostatSettings
    fun set(block: ThermostatSettings.() -> ThermostatSettings) = model.setThermostatSettings(s.block())
    SubScaffold(title = "Display Options", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SettingsCard {
                ToggleRow("Continuous Backlight", s.continuousBacklight) { set { copy(continuousBacklight = it) } }
                RowDivider()
                ToggleRow("Display Humidity", s.displayHumidity) { set { copy(displayHumidity = it) } }
                RowDivider()
                ToggleRow("Display Time", s.displayTime) { set { copy(displayTime = it) } }
                RowDivider()
                MenuRow(
                    title = "Temperature Units",
                    current = s.units,
                    options = TemperatureUnit.entries,
                    labelOf = { it.label },
                    onSelect = { set { copy(units = it) } },
                )
            }
        }
    }
}

@Composable
private fun SystemConfiguration(model: AppModel, state: AppState, onBack: () -> Unit) {
    val s = state.thermostatSettings
    fun set(block: ThermostatSettings.() -> ThermostatSettings) = model.setThermostatSettings(s.block())
    SubScaffold(title = "System Configuration", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SettingsCard {
                ToggleRow("Lock Thermostat", s.lockThermostat) { set { copy(lockThermostat = it) } }
            }
            SectionHeader("Temperature Limits")
            SettingsCard {
                StepperRow("Cooling Minimum", "${s.coolingMin}°",
                    onDecrement = { set { copy(coolingMin = coolingMin - 1) } },
                    onIncrement = { set { copy(coolingMin = coolingMin + 1) } })
                RowDivider()
                StepperRow("Heating Maximum", "${s.heatingMax}°",
                    onDecrement = { set { copy(heatingMax = heatingMax - 1) } },
                    onIncrement = { set { copy(heatingMax = heatingMax + 1) } })
            }
            SectionHeader("Humidity")
            SettingsCard {
                ToggleRow("Humidification", s.humidification) { set { copy(humidification = it) } }
                if (s.humidification) {
                    RowDivider()
                    StepperRow("Humidify To", "${s.humidifyTo}%",
                        onDecrement = { set { copy(humidifyTo = humidifyTo - 1) } },
                        onIncrement = { set { copy(humidifyTo = humidifyTo + 1) } })
                }
                RowDivider()
                ToggleRow("Dehumidification", s.dehumidification) { set { copy(dehumidification = it) } }
                if (s.dehumidification) {
                    RowDivider()
                    StepperRow("Dehumidify To", "${s.dehumidifyTo}%",
                        onDecrement = { set { copy(dehumidifyTo = dehumidifyTo - 1) } },
                        onIncrement = { set { copy(dehumidifyTo = dehumidifyTo + 1) } })
                }
            }
            SectionHeader("Boost")
            SettingsCard {
                MenuRow("Cooling Boost", s.coolingBoost, BOOST_OPTIONS, { it }) { set { copy(coolingBoost = it) } }
                RowDivider()
                MenuRow("Heating Boost", s.heatingBoost, BOOST_OPTIONS, { it }) { set { copy(heatingBoost = it) } }
                RowDivider()
                MenuRow("Aux Boost", s.auxBoost, BOOST_OPTIONS, { it }) { set { copy(auxBoost = it) } }
            }
            SectionHeader("Calibration")
            SettingsCard {
                StepperRow("Temperature Offset", "${s.temperatureOffset}°",
                    onDecrement = { set { copy(temperatureOffset = temperatureOffset - 1) } },
                    onIncrement = { set { copy(temperatureOffset = temperatureOffset + 1) } })
                RowDivider()
                StepperRow("Humidity Offset", "${s.humidityOffset}%",
                    onDecrement = { set { copy(humidityOffset = humidityOffset - 1) } },
                    onIncrement = { set { copy(humidityOffset = humidityOffset + 1) } })
                RowDivider()
                ToggleRow("AC Protection", s.acProtection) { set { copy(acProtection = it) } }
            }
        }
    }
}

@Composable
private fun AboutThermostat(state: AppState, onBack: () -> Unit) {
    var showRemove by remember { mutableStateOf(false) }
    SubScaffold(title = "About Thermostat", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SettingsCard {
                InfoRow("Name", state.device.name)
                RowDivider()
                InfoRow("Model", "1F86U-42WF")
                RowDivider()
                InfoRow("Firmware", "6004971003")
                RowDivider()
                InfoRow("MAC Address", "34:6F:92:00:00:00")
                RowDivider()
                InfoRow("Wi-Fi", "Strong")
                RowDivider()
                InfoRow("Battery", "Good")
            }
            SettingsCard {
                com.sensi.petticoat.ui.components.NavRow("Remove Thermostat") { showRemove = true }
            }
        }
    }
    if (showRemove) {
        AlertDialog(
            onDismissRequest = { showRemove = false },
            title = { Text("Remove Thermostat?") },
            text = { Text("This will unpair the thermostat from your account.") },
            confirmButton = {
                TextButton(onClick = { showRemove = false }) {
                    Text("Remove", color = Color(0xFFE0392B))
                }
            },
            dismissButton = {
                TextButton(onClick = { showRemove = false }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun LocationForm(model: AppModel, state: AppState, onBack: () -> Unit) {
    val s = state.thermostatSettings
    fun set(block: ThermostatSettings.() -> ThermostatSettings) = model.setThermostatSettings(s.block())
    SubScaffold(title = "Thermostat Location", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Field("Address", s.locationAddress) { set { copy(locationAddress = it) } }
            Field("Unit", s.locationUnit) { set { copy(locationUnit = it) } }
            Field("City", s.locationCity) { set { copy(locationCity = it) } }
            Field("State", s.locationState) { set { copy(locationState = it) } }
            Field("ZIP", s.locationZip) { set { copy(locationZip = it) } }
            Field("Country", s.locationCountry) { set { copy(locationCountry = it) } }
            TextButton(onClick = { /* stub: wire to location services */ }) {
                Text("Use Current Location")
            }
        }
    }
}

@Composable
private fun ContractorForm(model: AppModel, state: AppState, onBack: () -> Unit) {
    val c = state.contractor
    fun set(block: Contractor.() -> Contractor) = model.setContractor(c.block())
    SubScaffold(title = "Contractor Information", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Field("Company", c.company) { set { copy(company = it) } }
            Field("Address", c.address) { set { copy(address = it) } }
            Field("Phone", c.phone) { set { copy(phone = it) } }
            Field("City", c.city) { set { copy(city = it) } }
            Field("State", c.state) { set { copy(state = it) } }
            Field("Country", c.country) { set { copy(country = it) } }
        }
    }
}

@Composable
private fun EnergyPrograms(onBack: () -> Unit) {
    var enrolled by remember { mutableStateOf(false) }
    SubScaffold(title = "Energy Programs", onBack = onBack) { modifier ->
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SettingsCard {
                ToggleRow(
                    title = "EcoSmart Program",
                    checked = enrolled,
                    onCheckedChange = { enrolled = it },
                    subtitle = "Optimize energy usage during peak demand.",
                )
            }
        }
    }
}

@Composable
private fun Field(label: String, value: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun InfoRow(title: String, value: String) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp),
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
