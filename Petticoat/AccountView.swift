import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showChangePassword = false
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Personal Information") { PersonalInformationView() }
                    Button("Change Password") { showChangePassword = true }
                        .foregroundStyle(SMA.accent)
                }

                Section {
                    NavigationLink("Application Settings") { ApplicationSettingsView() }
                }

                Section {
                    NavigationLink("Notification Settings") { NotificationSettingsView() }
                }

                Section {
                    NavigationLink("Energy Programs") { PlaceholderDetail(title: "Energy Programs") }
                    NavigationLink("Smart Integrations") { PlaceholderDetail(title: "Smart Integrations") }
                }

                Section {
                    NavigationLink("About Application") { AboutApplicationView() }
                }

                Section {
                    Button { showHelp = true } label: {
                        LinkRow(title: "Help and Support", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.plain)
                    NavigationLink("Feedback") { PlaceholderDetail(title: "Feedback") }
                }

                Section {
                    Button("Logout", role: .destructive) { showLogoutConfirm = true }
                        .foregroundStyle(SMA.destructive)
                }

                Section {
                    Button("Delete Account", role: .destructive) { showDeleteConfirm = true }
                        .foregroundStyle(SMA.destructive)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .listRowBackground(SMA.card)
            .foregroundStyle(SMA.labelPrimary)
            .navigationTitle("Account")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SMA.labelPrimary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showHelp = true } label: {
                        Image(systemName: "questionmark.bubble")
                            .foregroundStyle(SMA.labelPrimary)
                    }
                    .accessibilityLabel("Help and Support")
                }
            }
            .sheet(isPresented: $showChangePassword) { ChangePasswordView() }
            .sheet(isPresented: $showHelp) { HelpSupportView() }
            .confirmationDialog("Log out of Sensi?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Logout", role: .destructive) { model.signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete your Sensi account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    dismiss()
                    model.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and cannot be undone.")
            }
        }
    }
}

// MARK: - Rows

private struct LinkRow: View {
    let title: String
    let systemImage: String
    var body: some View {
        HStack {
            Text(title).foregroundStyle(SMA.labelPrimary)
            Spacer()
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SMA.labelSecondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail screens

struct PersonalInformationView: View {
    @State private var firstName = "Alex"
    @State private var lastName = "Morgan"
    @State private var email = "alex.morgan@example.com"
    @State private var phone = "(314) 555-0142"

    var body: some View {
        Form {
            Section {
                labeledField("First Name", text: $firstName)
                labeledField("Last Name", text: $lastName)
                labeledField("Email", text: $email)
                labeledField("Phone", text: $phone)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .listRowBackground(SMA.card)
        .navigationTitle("Personal Information")
        .inlineNavTitle()
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(SMA.labelSecondary)
            Spacer()
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(SMA.labelPrimary)
        }
    }
}

/// App-wide settings merged with dashboard organization: appearance, weather
/// display, section/card ordering, spotlight visibility, and display options.
/// Reordering happens in Edit mode (toolbar Edit button); toggles and the
/// appearance picker are interactive otherwise.
struct ApplicationSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                AppearancePicker(selection: $model.appearance)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
            } header: {
                Text("Appearance")
            } footer: {
                Text("Match appearance to your phone’s Display & Brightness settings.")
            }

            Section {
                Toggle("Weather Location", isOn: $model.showWeatherLocation)
                    .tint(Color(hex: 0x34C759))
                    .foregroundStyle(SMA.labelPrimary)
            } footer: {
                Text("Display the location of the outdoor weather on the control screen.")
            }

            Section {
                ForEach(model.dashboardSectionOrder) { section in
                    Text(section.title).foregroundStyle(SMA.labelPrimary)
                }
                .onMove { model.moveDashboardSections(from: $0, to: $1) }
            } header: {
                Text("Dashboard Sections")
            } footer: {
                Text("Drag to reorder how sections appear on the dashboard.")
            }

            Section {
                ForEach(model.devices) { device in
                    HStack(spacing: 12) {
                        Label(device.name, image: "thermostat.fill")
                            .foregroundStyle(SMA.labelPrimary)
                        Spacer()
                        Text(device.location)
                            .font(.footnote)
                            .foregroundStyle(SMA.labelSecondary)
                    }
                }
                .onMove { model.moveDevices(from: $0, to: $1) }
            } header: {
                Text("Thermostats")
            }

            Section {
                ForEach(model.spotlights) { item in
                    Toggle(isOn: Binding(
                        get: { !model.hiddenSpotlights.contains(item.id) },
                        set: { model.setSpotlight(item, hidden: !$0) }
                    )) {
                        Text(item.title)
                            .foregroundStyle(SMA.labelPrimary)
                            .lineLimit(1)
                    }
                    .tint(Color(hex: 0x34C759))
                }
                .onMove { model.moveSpotlights(from: $0, to: $1) }
            } header: {
                Text("Spotlight")
            } footer: {
                Text("Turn cards on or off, or drag to reorder them.")
            }

            Section {
                Toggle("Show Sensors on Dashboard", isOn: $model.showSensorsOnDashboard)
                    .tint(Color(hex: 0x34C759))
                    .foregroundStyle(SMA.labelPrimary)
            } header: {
                Text("Display")
            } footer: {
                Text("Show the participating-sensor selection under each thermostat card.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .listRowBackground(SMA.card)
        .foregroundStyle(SMA.labelPrimary)
        .navigationTitle("Application Settings")
        .inlineNavTitle()
        .toolbar { EditButton() }
    }
}

/// Light / System / Dark picker with mini thermostat-screen swatches.
struct AppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(AppAppearance.allCases) { option in
                VStack(spacing: 8) {
                    ThermostatSwatch(appearance: option)
                    Text(option.title)
                        .font(.subheadline)
                        .foregroundStyle(SMA.labelPrimary)
                    Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selection == option ? SMA.accent : SMA.labelSecondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.snappy) { selection = option } }
                .accessibilityElement()
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selection == option ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A small thermostat-screen mock for the appearance picker: light, dark, or a
/// diagonally split "system" preview showing both.
struct ThermostatSwatch: View {
    let appearance: AppAppearance

    var body: some View {
        Group {
            switch appearance {
            case .light: face(dark: false)
            case .dark:  face(dark: true)
            case .system:
                ZStack {
                    face(dark: false)
                    face(dark: true).mask {
                        GeometryReader { geo in
                            Path { p in
                                p.move(to: .zero)
                                p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                                p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                p.closeSubpath()
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 60, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private func face(dark: Bool) -> some View {
        let bar = (dark ? Color.white : Color.black).opacity(0.15)
        let modeBar = (dark ? Color.white : Color.black).opacity(0.2)
        return ZStack {
            (dark ? Color.black : Color(hex: 0xF2F2F7))
            VStack(spacing: 4) {
                Capsule().fill(bar).frame(width: 16, height: 6)
                Text("72")
                    .font(.custom("Lato-Regular", size: 22))
                    .foregroundStyle(Color(hex: 0x0093C8))
                Capsule().fill(bar).frame(width: 14, height: 8)
            }
            .offset(y: -6)
            VStack(spacing: 5) {
                Spacer()
                RoundedRectangle(cornerRadius: 3).fill(modeBar)
                    .frame(height: 16)
                    .padding(.horizontal, 2)
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule().fill(bar).frame(width: 4, height: 8)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }
}

struct NotificationSettingsView: View {
    @State private var smartAlerts = true
    @State private var energyReports = false
    @State private var offers = true
    @State private var deviceStatus = true

    var body: some View {
        Form {
            Section {
                toggle("Smart Alerts", isOn: $smartAlerts)
                toggle("Energy Reports", isOn: $energyReports)
                toggle("Info & Offers", isOn: $offers)
                toggle("Device Status", isOn: $deviceStatus)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .listRowBackground(SMA.card)
        .navigationTitle("Notification Settings")
        .inlineNavTitle()
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(Color(hex: 0x34C759))
            .foregroundStyle(SMA.labelPrimary)
    }
}

struct PlaceholderDetail: View {
    let title: String
    var body: some View {
        ContentUnavailableView {
            Label("Coming Soon", systemImage: "sparkles")
        } description: {
            Text("\(title) isn't available yet. Check back in a future update.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle(title)
        .inlineNavTitle()
    }
}

// MARK: - Change password

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var saved = false

    /// Local-only validation for the demo: all fields present, new matches confirm,
    /// new is long enough and differs from the current password.
    private var isValid: Bool {
        !current.isEmpty && new.count >= 8 && new == confirm && new != current
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $current)
                    SecureField("New Password", text: $new)
                    SecureField("Confirm New Password", text: $confirm)
                } footer: {
                    Text("Your new password must be at least 8 characters and different from your current one.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .listRowBackground(SMA.card)
            .navigationTitle("Change Password")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saved = true }
                        .disabled(!isValid)
                }
            }
            .alert("Password Changed", isPresented: $saved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your password has been updated.")
            }
        }
    }
}

// MARK: - Help & Support

/// Lightweight in-app help hub. Shared by the dashboard and account screens.
struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Getting Started") { PlaceholderDetail(title: "Getting Started") }
                    NavigationLink("Thermostat Setup") { PlaceholderDetail(title: "Thermostat Setup") }
                    NavigationLink("Schedules & Presets") { PlaceholderDetail(title: "Schedules & Presets") }
                    NavigationLink("Troubleshooting") { PlaceholderDetail(title: "Troubleshooting") }
                } header: {
                    Text("Help Topics")
                }

                Section {
                    LinkRow(title: "Contact Support", systemImage: "envelope")
                    LinkRow(title: "Call Us", systemImage: "phone")
                } header: {
                    Text("Get in Touch")
                } footer: {
                    Text("Support is available 7 days a week, 7am–9pm CT.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .listRowBackground(SMA.card)
            .foregroundStyle(SMA.labelPrimary)
            .navigationTitle("Help & Support")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SMA.labelPrimary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

// MARK: - About

struct AboutApplicationView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image("sensi.logo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 32)
                        .foregroundStyle(SMA.brandNavy)
                        .accessibilityHidden(true)
                    Text("Sensi")
                        .font(.headline)
                        .foregroundStyle(SMA.labelPrimary)
                    Text("Version \(version) (\(build))")
                        .font(.footnote)
                        .foregroundStyle(SMA.labelSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Build", value: build)
            }

            Section {
                LinkRow(title: "Privacy Policy", systemImage: "arrow.up.right")
                LinkRow(title: "Terms of Service", systemImage: "arrow.up.right")
                LinkRow(title: "Acknowledgements", systemImage: "arrow.up.right")
            }

            Section {
                Text("© 2026 Copeland LP. All rights reserved.")
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .listRowBackground(SMA.card)
        .foregroundStyle(SMA.labelPrimary)
        .navigationTitle("About")
        .inlineNavTitle()
    }
}

#Preview {
    AccountView()
        .environment(AppModel())
}

#Preview("Application Settings") {
    NavigationStack { ApplicationSettingsView() }
        .environment(AppModel())
}
