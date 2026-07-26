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
    @Environment(\.openURL) private var openURL

    @State private var company = "123 HVAC Contracting Company"
    @State private var address = "ABC Ave"
    @State private var phone = "555555"
    @State private var city = "Villagetownsburg"
    @State private var state = "Missouri"
    @State private var country = "United States"
    @State private var confirmRemove = false

    private var phoneDigits: String { phone.filter(\.isNumber) }

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
                RowActionButton("Call Contractor", isEnabled: !phoneDigits.isEmpty) {
                    if let url = URL(string: "tel://\(phoneDigits)") { openURL(url) }
                }
            }

            Section {
                RowActionButton("Remove Contractor", role: .destructive) { confirmRemove = true }
            }
        }
        .groupedListChrome()
        .navigationTitle("Contractor Information")
        .inlineNavTitle()
        .confirmationDialog("Remove this contractor?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove Contractor", role: .destructive) {
                company = ""; address = ""; phone = ""; city = ""; state = ""; country = ""
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Their contact information will be removed from this thermostat.")
        }
    }
}

// MARK: - Energy Programs

struct EnergyProgram: Identifiable, Hashable {
    let id = UUID()
    let provider: String
    let expires: String?
    var enrolled: Bool
}

struct EnergyProgramsView: View {
    @State private var programs = [
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
                            EnergyProgramDetailView(program: program) { enroll(program.id) }
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

    private func enroll(_ id: EnergyProgram.ID) {
        guard let i = programs.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { programs[i].enrolled = true }
    }
}

struct EnergyProgramDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let program: EnergyProgram
    let onEnroll: () -> Void

    @State private var confirmEnroll = false

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
                RowActionButton("Enroll") { confirmEnroll = true }
            }
        }
        .groupedListChrome()
        .navigationTitle(program.provider)
        .inlineNavTitle()
        .confirmationDialog("Enroll in \(program.provider)?", isPresented: $confirmEnroll, titleVisibility: .visible) {
            Button("Enroll") { onEnroll(); dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can unenroll anytime by contacting \(program.provider).")
        }
    }
}

// MARK: - System Configuration

struct SystemConfigurationView: View {
    @State private var lockThermostat = false
    @State private var coolingMin = 55
    @State private var heatingMax = 99
    @State private var humidification = true
    @State private var humidifyTo = 40
    @State private var dehumidification = true
    @State private var dehumidifyTo = 40
    @State private var coolingBoost = "Comfort"
    @State private var heatingBoost = "Comfort"
    @State private var auxBoost = "Comfort"
    @State private var temperatureOffset = 0
    @State private var humidityOffset = 0
    @State private var acProtection = true

    private let boostOptions = ["Off", "Eco", "Comfort", "Fast"]

    var body: some View {
        List {
            Section {
                Toggle("Lock Thermostat", isOn: $lockThermostat)
            } footer: {
                Text("Disables functionality on the thermostat allowing control only through the app.")
            }

            Section("Temperature Limits") {
                Picker("Cooling Min", selection: $coolingMin) {
                    ForEach(45...80, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Heating Max", selection: $heatingMax) {
                    ForEach(60...99, id: \.self) { Text("\($0)").tag($0) }
                }
            }

            Section("Humidity Control") {
                Toggle("Humidification", isOn: $humidification)
                Picker("Humidify to", selection: $humidifyTo) {
                    ForEach(Array(stride(from: 10, through: 60, by: 5)), id: \.self) { Text("\($0)%").tag($0) }
                }
            }

            Section {
                Toggle("Dehumidification", isOn: $dehumidification)
                Picker("Dehumidify to", selection: $dehumidifyTo) {
                    ForEach(Array(stride(from: 30, through: 70, by: 5)), id: \.self) { Text("\($0)%").tag($0) }
                }
            } footer: {
                Text("Your desired humidity may not be able to be reached in your home. In some cases too high or too low of humidity can cause damage in your home.")
            }

            Section {
                Picker("Cooling", selection: $coolingBoost) { ForEach(boostOptions, id: \.self) { Text($0).tag($0) } }
                Picker("Heating", selection: $heatingBoost) { ForEach(boostOptions, id: \.self) { Text($0).tag($0) } }
                Picker("AUX Heat", selection: $auxBoost) { ForEach(boostOptions, id: \.self) { Text($0).tag($0) } }
            } header: {
                Text("Boost")
            } footer: {
                Text("Faster cycle rates provide tighter temperature control and shorter on/off cycles. Slow cycle rates allow for a wider temperature swing and longer on/off cycles.")
            }

            Section("Offsets") {
                Stepper(value: $temperatureOffset, in: -5...5) {
                    LabeledContent("Temperature", value: "\(temperatureOffset)")
                }
                Stepper(value: $humidityOffset, in: -10...10) {
                    LabeledContent("Humidity", value: "\(humidityOffset)%")
                }
            }

            Section {
                Toggle("AC Protection", isOn: $acProtection)
            } header: {
                Text("Miscellaneous")
            } footer: {
                Text("Short delay when AC is quickly turned OFF then ON to prevent equipment damage.")
            }
        }
        .groupedListChrome()
        .navigationTitle("System Configuration")
        .inlineNavTitle()
    }
}

// MARK: - About Thermostat

struct AboutThermostatView: View {
    @State private var name = ""
    @State private var confirmRemove = false

    var body: some View {
        List {
            Section {
                TextField("Thermostat Name", text: $name)
            }

            Section {
                NavigationLink("Thermostat Location") { ThermostatLocationView() }
            }

            Section {
                LabeledContent("Wi-Fi Strength", value: "50 RSSI (Good)")
                MetricBar(progress: 0.8).listRowSeparator(.hidden)
            }

            Section {
                LabeledContent("Battery Strength", value: "2.4 V (Fair)")
                MetricBar(progress: 0.45).listRowSeparator(.hidden)
            }

            Section("Hardware Information") {
                LabeledContent("Model", value: "1F86U-42WF")
                LabeledContent("Firmware Version", value: "6004971003")
                LabeledContent("MAC Address", value: "34:6F:92:06:E1:C6")
            }

            Section("HVAC Equipment") {
                LabeledContent("Current Runtime", value: "0:00:00")
                LabeledContent("Indoor Configuration", value: "Electric")
                LabeledContent("Indoor Stages", value: "1")
                LabeledContent("Outdoor Configuration", value: "AC")
                LabeledContent("Outdoor Stages", value: "1")
            }

            Section {
                RowActionButton("Remove Thermostat", role: .destructive) { confirmRemove = true }
            }
        }
        .groupedListChrome()
        .navigationTitle("About Thermostat")
        .inlineNavTitle()
        .confirmationDialog("Remove this thermostat?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove Thermostat", role: .destructive) { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll need to set it up again to control it from the app.")
        }
    }
}

// MARK: - Thermostat Location

struct ThermostatLocationView: View {
    @State private var address = ""
    @State private var unit = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var country = "United States"

    var body: some View {
        List {
            Section("Location") {
                TextField("Address", text: $address)
                TextField("Apt / Suite", text: $unit)
                TextField("City", text: $city)
                TextField("State", text: $state)
                TextField("ZIP Code", text: $zip)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Country", text: $country)
            }

            Section {
                Button {
                } label: {
                    Label("Use Current Location", systemImage: "location.fill")
                }
            }
        }
        .groupedListChrome()
        .navigationTitle("Thermostat Location")
        .inlineNavTitle()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .inlineNavTitle()
    }
    .environment(AppModel())
}
