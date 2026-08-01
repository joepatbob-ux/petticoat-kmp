package com.sensi.petticoat.model

enum class InstallStepKind { Standard, Wifi, Pin, WirePicker, Form, Complete }
enum class ThermostatModel { Touch2, Touch, Lite, Classic, Sensor }

data class InstallStep(
    val id: String = newId(),
    val stage: String,
    val kind: InstallStepKind = InstallStepKind.Standard,
    val title: String,
    val body: String,
)

data class InstallDevice(
    val id: String = newId(),
    val name: String,
    val subtitle: String,
    val model: ThermostatModel,
    val steps: List<InstallStep>,
) {
    val isRoomSensor: Boolean get() = model == ThermostatModel.Sensor
}

object InstallCatalog {
    private fun thermostatSteps() = listOf(
        InstallStep(stage = "Getting Started", title = "Before you begin", body = "Gather tools and turn off HVAC power."),
        InstallStep(stage = "Install", title = "Remove your old thermostat", body = "Photograph and label the existing wires."),
        InstallStep(stage = "Install", kind = InstallStepKind.WirePicker, title = "Select your wires", body = "Choose every connected terminal."),
        InstallStep(stage = "Connect", kind = InstallStepKind.Wifi, title = "Connect to Wi‑Fi", body = "Choose your home network."),
        InstallStep(stage = "Register", kind = InstallStepKind.Pin, title = "Enter the PIN", body = "Enter the code shown on the thermostat."),
        InstallStep(stage = "Setup Complete", kind = InstallStepKind.Complete, title = "Setup complete", body = "Your thermostat is ready."),
    )

    val devices = listOf(
        InstallDevice(name = "Sensi Touch 2", subtitle = "Color touchscreen thermostat", model = ThermostatModel.Touch2, steps = thermostatSteps()),
        InstallDevice(name = "Sensi Touch", subtitle = "Smart touchscreen thermostat", model = ThermostatModel.Touch, steps = thermostatSteps()),
        InstallDevice(name = "Sensi Lite", subtitle = "Simple smart thermostat", model = ThermostatModel.Lite, steps = thermostatSteps()),
        InstallDevice(name = "Sensi Classic", subtitle = "Wi‑Fi thermostat", model = ThermostatModel.Classic, steps = thermostatSteps()),
        InstallDevice(
            name = "Sensi Room Sensor",
            subtitle = "Remote temperature and humidity",
            model = ThermostatModel.Sensor,
            steps = listOf(InstallStep(stage = "Pair", kind = InstallStepKind.Complete, title = "Pair room sensor", body = "Press and hold the sensor button until the light flashes.")),
        ),
    )
}

object WireConfigValidator {
    val terminalOrder = listOf("R", "W", "Y", "G", "RH", "W1", "Y1", "O", "RC", "W/E", "Y2", "B", "C", "W2", "L", "O/B", "X", "E", "AUX")
    private val configs = listOf(
        setOf("R", "W", "Y", "G"),
        setOf("RC", "RH", "W", "Y", "G"),
        setOf("R", "C", "Y", "G", "O/B"),
        setOf("R", "C", "Y1", "Y2", "G", "O/B", "AUX"),
    )

    fun allowed(selection: Set<String>): Set<String> =
        configs.filter { it.containsAll(selection) }.flatten().toSet()

    fun isValid(selection: Set<String>): Boolean = selection.isNotEmpty() && selection in configs
}
