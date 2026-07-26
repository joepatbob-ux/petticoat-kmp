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

/// All persisted thermostat settings (Display Options, System Configuration, About, and
/// Location). Stored on `AppModel` so edits survive navigating away and back.
@Observable final class ThermostatSettings {
    // A reference type so SwiftUI observes each field individually — flipping one
    // toggle/picker only invalidates that control, not the whole Settings screen.

    // Display Options
    var continuousBacklight = true
    var displayHumidity = true
    var displayTime = true
    var units: TemperatureUnit = .fahrenheit

    // System Configuration
    var lockThermostat = false
    var coolingMin = 55
    var heatingMax = 99
    var humidification = true
    var humidifyTo = 40
    var dehumidification = true
    var dehumidifyTo = 40
    var coolingBoost = "Comfort"
    var heatingBoost = "Comfort"
    var auxBoost = "Comfort"
    var temperatureOffset = 0
    var humidityOffset = 0
    var acProtection = true

    // About / Location
    var name = ""
    var locationAddress = ""
    var locationUnit = ""
    var locationCity = ""
    var locationState = ""
    var locationZip = ""
    var locationCountry = "United States"
}

struct DisplayOptionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Toggle("Continuous Backlight", isOn: $model.thermostatSettings.continuousBacklight)
            } footer: {
                Text("Backlight will remain on at all times.")
            }
            Section {
                Toggle("Display Humidity", isOn: $model.thermostatSettings.displayHumidity)
            } footer: {
                Text("Show humidity level on the thermostat.")
            }
            Section {
                Toggle("Display Time", isOn: $model.thermostatSettings.displayTime)
            } footer: {
                Text("Show time on the thermostat.")
            }
            Section {
                Picker("Temperature Units", selection: $model.thermostatSettings.units) {
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

/// The HVAC contractor on file for this thermostat. Stored on `AppModel` so Settings and
/// the reminder "Call Contractor" action share one source of truth. A reference type so
/// editing one field doesn't invalidate every field's view.
@Observable final class Contractor {
    var company: String
    var address: String
    var phone: String
    var city: String
    var state: String
    var country: String

    init(company: String = "", address: String = "", phone: String = "",
         city: String = "", state: String = "", country: String = "") {
        self.company = company
        self.address = address
        self.phone = phone
        self.city = city
        self.state = state
        self.country = country
    }

    /// Digits only, for a `tel:` URL.
    var phoneDigits: String { phone.filter(\.isNumber) }

    static var sample: Contractor {
        Contractor(company: "123 HVAC Contracting Company", address: "ABC Ave", phone: "555555",
                   city: "Villagetownsburg", state: "Missouri", country: "United States")
    }
}

struct ContractorInformationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var confirmRemove = false

    var body: some View {
        @Bindable var model = model
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
                TextField("Company", text: $model.contractor.company)
                TextField("Address", text: $model.contractor.address)
                TextField("Phone", text: $model.contractor.phone)
                    .keyboardType(.phonePad)
                TextField("City", text: $model.contractor.city)
                TextField("State", text: $model.contractor.state)
                TextField("Country", text: $model.contractor.country)
            }

            Section {
                RowActionButton("Call Contractor", isEnabled: !model.contractor.phoneDigits.isEmpty) {
                    if let url = URL(string: "tel://\(model.contractor.phoneDigits)") { openURL(url) }
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
            Button("Remove Contractor", role: .destructive) { model.contractor = Contractor() }
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
    @Environment(AppModel.self) private var model

    private let boostOptions = ["Off", "Eco", "Comfort", "Fast"]

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Toggle("Lock Thermostat", isOn: $model.thermostatSettings.lockThermostat)
            } footer: {
                Text("Disables functionality on the thermostat allowing control only through the app.")
            }

            Section("Temperature Limits") {
                Picker("Cooling Min", selection: $model.thermostatSettings.coolingMin) {
                    ForEach(45...80, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Heating Max", selection: $model.thermostatSettings.heatingMax) {
                    ForEach(60...99, id: \.self) { Text("\($0)").tag($0) }
                }
            }

            Section("Humidity Control") {
                Toggle("Humidification", isOn: $model.thermostatSettings.humidification)
                Picker("Humidify to", selection: $model.thermostatSettings.humidifyTo) {
                    ForEach(Array(stride(from: 10, through: 60, by: 5)), id: \.self) { Text("\($0)%").tag($0) }
                }
            }

            Section {
                Toggle("Dehumidification", isOn: $model.thermostatSettings.dehumidification)
                Picker("Dehumidify to", selection: $model.thermostatSettings.dehumidifyTo) {
                    ForEach(Array(stride(from: 30, through: 70, by: 5)), id: \.self) { Text("\($0)%").tag($0) }
                }
            } footer: {
                Text("Your desired humidity may not be able to be reached in your home. In some cases too high or too low of humidity can cause damage in your home.")
            }

            Section {
                Picker("Cooling", selection: $model.thermostatSettings.coolingBoost) { ForEach(boostOptions, id: \.self) { Text($0).tag($0) } }
                Picker("Heating", selection: $model.thermostatSettings.heatingBoost) { ForEach(boostOptions, id: \.self) { Text($0).tag($0) } }
                Picker("AUX Heat", selection: $model.thermostatSettings.auxBoost) { ForEach(boostOptions, id: \.self) { Text($0).tag($0) } }
            } header: {
                Text("Boost")
            } footer: {
                Text("Faster cycle rates provide tighter temperature control and shorter on/off cycles. Slow cycle rates allow for a wider temperature swing and longer on/off cycles.")
            }

            Section("Offsets") {
                Stepper(value: $model.thermostatSettings.temperatureOffset, in: -5...5) {
                    LabeledContent("Temperature", value: "\(model.thermostatSettings.temperatureOffset)")
                }
                Stepper(value: $model.thermostatSettings.humidityOffset, in: -10...10) {
                    LabeledContent("Humidity", value: "\(model.thermostatSettings.humidityOffset)%")
                }
            }

            Section {
                Toggle("AC Protection", isOn: $model.thermostatSettings.acProtection)
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
    @Environment(AppModel.self) private var model
    @State private var confirmRemove = false

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                TextField("Thermostat Name", text: $model.thermostatSettings.name)
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
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List {
            Section("Location") {
                TextField("Address", text: $model.thermostatSettings.locationAddress)
                TextField("Apt / Suite", text: $model.thermostatSettings.locationUnit)
                TextField("City", text: $model.thermostatSettings.locationCity)
                TextField("State", text: $model.thermostatSettings.locationState)
                TextField("ZIP Code", text: $model.thermostatSettings.locationZip)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Country", text: $model.thermostatSettings.locationCountry)
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
