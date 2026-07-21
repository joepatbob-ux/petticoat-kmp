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
                    NavigationLink("Notification Settings") { NotificationSettingsView() }
                }

                Section {
                    NavigationLink("Energy Programs") { PlaceholderDetail(title: "Energy Programs") }
                    NavigationLink("Smart Integrations") { PlaceholderDetail(title: "Smart Integrations") }
                }

                Section {
                    NavigationLink("About Application") { AboutApplicationView() }
                    NavigationLink("Application Options") { PlaceholderDetail(title: "Application Options") }
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
        }
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
