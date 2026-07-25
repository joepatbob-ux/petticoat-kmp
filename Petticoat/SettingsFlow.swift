import SwiftUI

// MARK: - Thermostat Settings
//
// The Settings device tab: a menu of thermostat settings that drill into detail
// screens. Service Reminders live in their own Reminders tab, so they're not
// duplicated here. Prototype-local state.

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Display Options") { DisplayOptionsView() }
                NavigationLink("System Configuration") { SystemConfigurationView() }
            }
            Section {
                NavigationLink("About Thermostat") { AboutThermostatView() }
            }
            Section {
                NavigationLink("Contractor Information") { ContractorInformationView() }
            }
            Section {
                NavigationLink("Energy Programs") { EnergyProgramsView() }
            }
        }
        .groupedListChrome()
    }
}

// MARK: - Display Options

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case fahrenheit, celsius
    var id: String { rawValue }
    var label: String { self == .fahrenheit ? "°F" : "°C" }
}

struct DisplayOptionsView: View {
    @State private var continuousBacklight = true
    @State private var displayHumidity = true
    @State private var displayTime = true
    @State private var units: TemperatureUnit = .fahrenheit

    var body: some View {
        List {
            Section {
                Toggle("Continuous Backlight", isOn: $continuousBacklight)
            } footer: {
                Text("Backlight will remain on at all times.")
            }
            Section {
                Toggle("Display Humidity", isOn: $displayHumidity)
            } footer: {
                Text("Show humidity level on the thermostat.")
            }
            Section {
                Toggle("Display Time", isOn: $displayTime)
            } footer: {
                Text("Show time on the thermostat.")
            }
            Section {
                Picker("Temperature Units", selection: $units) {
                    ForEach(TemperatureUnit.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .groupedListChrome()
        .navigationTitle("Display Options")
        .inlineNavTitle()
    }
}

// MARK: - Contractor Information

struct ContractorInformationView: View {
    @State private var company = "123 HVAC Contracting Company"
    @State private var address = "ABC Ave"
    @State private var phone = "555555"
    @State private var city = "Villagetownsburg"
    @State private var state = "Missouri"
    @State private var country = "United States"

    var body: some View {
        List {
            Section {
                // Placeholder for the contractor illustration (design asset not bundled).
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(SMA.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityHidden(true)
            }

            Section {
                TextField("Company", text: $company)
                TextField("Address", text: $address)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("City", text: $city)
                TextField("State", text: $state)
                TextField("Country", text: $country)
            }

            Section {
                Button("Call Contractor") { }
                    .frame(maxWidth: .infinity)
            }

            Section {
                Button("Remove Contractor", role: .destructive) { }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(SMA.destructive)
            }
        }
        .groupedListChrome()
        .navigationTitle("Contractor Information")
        .inlineNavTitle()
    }
}

// MARK: - Energy Programs

struct EnergyProgram: Identifiable, Hashable {
    let id = UUID()
    let provider: String
    let expires: String?
    let enrolled: Bool
}

struct EnergyProgramsView: View {
    private let programs = [
        EnergyProgram(provider: "Ameren", expires: "March 20, 2025", enrolled: false),
        EnergyProgram(provider: "Ameren", expires: "March 20, 2025", enrolled: false),
        EnergyProgram(provider: "Ameren", expires: nil, enrolled: true),
    ]

    var body: some View {
        List {
            Section {
                Text("Sensi found the following programs in your area that could help save you money.")
                    .foregroundStyle(SMA.labelPrimary)
            }

            Section {
                ForEach(programs) { program in
                    if program.enrolled {
                        LabeledContent {
                            Text("Enrolled").foregroundStyle(SMA.labelSecondary)
                        } label: {
                            Text(program.provider).foregroundStyle(SMA.labelPrimary)
                        }
                    } else {
                        NavigationLink {
                            EnergyProgramDetailView(program: program)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(program.provider)
                                    .foregroundStyle(SMA.labelPrimary)
                                if let expires = program.expires {
                                    Text("Expires: \(expires)")
                                        .font(.footnote)
                                        .foregroundStyle(SMA.labelSecondary)
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text("To unenroll from the program, please reach out to your program provider for further details.")
            }
        }
        .groupedListChrome()
        .navigationTitle("Energy Programs")
        .inlineNavTitle()
    }
}

struct EnergyProgramDetailView: View {
    let program: EnergyProgram

    var body: some View {
        List {
            Section {
                Text("Enroll in the \(program.provider) energy program to earn savings during peak demand events. Your thermostat may make small temperature adjustments you can always override.")
                    .foregroundStyle(SMA.labelPrimary)
            } footer: {
                if let expires = program.expires {
                    Text("Enrollment closes \(expires).")
                }
            }
            Section {
                Button("Enroll") { }
                    .frame(maxWidth: .infinity)
            }
        }
        .groupedListChrome()
        .navigationTitle(program.provider)
        .inlineNavTitle()
    }
}

// MARK: - Placeholders for the larger settings screens

/// A titled "coming soon" placeholder for a settings detail that isn't built yet.
private struct SettingsStub: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text("Prototype screen"))
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(title)
            .inlineNavTitle()
    }
}

struct SystemConfigurationView: View {
    var body: some View { SettingsStub(title: "System Configuration", systemImage: "gearshape.2") }
}

struct AboutThermostatView: View {
    var body: some View { SettingsStub(title: "About Thermostat", systemImage: "info.circle") }
}

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .inlineNavTitle()
    }
    .environment(AppModel())
}
