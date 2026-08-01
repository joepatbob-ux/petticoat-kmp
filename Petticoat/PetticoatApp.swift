import SwiftUI

@main
struct MyApp: App {
    /// Owned at the scene level so the iPad menu bar (`PetticoatCommands`) and the
    /// window content (`RootView`) share one model instance.
    @State private var model = AppModel()

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .commands {
            PetticoatCommands(model: model)
        }
    }
}

/// The iPad hardware-keyboard menu bar. It surfaces actions the app already has —
/// wired to the shared `AppModel` so the menus, keyboard shortcuts, and the on-screen
/// sidebar/detail stay in sync. Inert on iPhone (no menu bar), where the shortcuts are
/// simply a bonus for attached keyboards.
struct PetticoatCommands: Commands {
    var model: AppModel

    var body: some Commands {
        // File ▸ Add a Device / New Reminder
        CommandGroup(replacing: .newItem) {
            Button("Add a Device…") { model.setShowAddDevice(true) }
                .keyboardShortcut("n", modifiers: .command)
            Button("New Reminder…") { model.setAddingReminder(true) }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.devices.isEmpty)
        }

        // View ▸ Dashboard toggle + tab switching (⌘0, ⌘1–⌘5)
        CommandGroup(after: .sidebar) {
            Button(model.sidebarVisible ? "Hide Dashboard" : "Show Dashboard") {
                model.setSidebarVisible(!model.sidebarVisible)
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Group {
                ForEach(Array(DeviceTab.allCases.enumerated()), id: \.element) { index, tab in
                    Button(tab.label) { model.setSelectedTab(tab) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            .disabled(model.devices.isEmpty)
        }

        // Thermostat ▸ switch device, set mode, nudge setpoint, presets
        CommandMenu("Thermostat") {
            Group {
                if model.devices.count > 1 {
                    Menu("Switch Thermostat") {
                        ForEach(model.devices) { device in
                            Button(device.name) { model.selectDevice(device.id) }
                        }
                    }
                    Divider()
                }

                Menu("Set Mode") {
                    Button("Heat") { model.setSystemMode(.heat, for: model.device.id) }
                    Button("Cool") { model.setSystemMode(.cool, for: model.device.id) }
                    Button("Auto") { model.setSystemMode(.auto, for: model.device.id) }
                    Button("Off")  { model.setSystemMode(.off, for: model.device.id) }
                }

                Button("Raise Temperature") { model.nudgeSetpoint(by: 1) }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button("Lower Temperature") { model.nudgeSetpoint(by: -1) }
                    .keyboardShortcut(.downArrow, modifiers: .command)

                Divider()

                Button("Home") { model.activateProfileNamed("Home") }
                Button("Away") { model.activateProfileNamed("Away") }
            }
            .disabled(model.devices.isEmpty)
        }

        // Help ▸ Sensi Help & Support
        CommandGroup(replacing: .help) {
            Button("Sensi Help & Support") { model.setShowHelp(true) }
        }
    }
}
