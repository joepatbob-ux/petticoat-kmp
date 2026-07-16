import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    group {
                        NavigationRow(title: "Personal Information") { PersonalInformationView() }
                        Divider().overlay(SMA.separator).padding(.leading, 16)
                        Button("Change Password") {}
                            .buttonStyle(.plain)
                            .foregroundStyle(SMA.accent)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    group {
                        NavigationRow(title: "Notification Settings") { NotificationSettingsView() }
                    }

                    group {
                        NavigationRow(title: "Energy Programs") { PlaceholderDetail(title: "Energy Programs") }
                        Divider().overlay(SMA.separator).padding(.leading, 16)
                        NavigationRow(title: "Smart Integrations") { PlaceholderDetail(title: "Smart Integrations") }
                    }

                    group {
                        NavigationRow(title: "About Application") { PlaceholderDetail(title: "About Application") }
                        Divider().overlay(SMA.separator).padding(.leading, 16)
                        NavigationRow(title: "Application Options") { PlaceholderDetail(title: "Application Options") }
                    }

                    group {
                        LinkRow(title: "Help and Support", systemImage: "arrow.up.right")
                        Divider().overlay(SMA.separator).padding(.leading, 16)
                        NavigationRow(title: "Feedback") { PlaceholderDetail(title: "Feedback") }
                    }

                    group {
                        Button("Logout") { showLogoutConfirm = true }
                            .buttonStyle(.plain)
                            .foregroundStyle(SMA.destructive)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    group {
                        Button("Delete Account") {}
                            .buttonStyle(.plain)
                            .foregroundStyle(SMA.destructive)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .background(SMA.groupedBackground.ignoresSafeArea())
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
                    Image(systemName: "questionmark.bubble")
                        .foregroundStyle(SMA.labelPrimary)
                }
            }
            .confirmationDialog("Log out of Sensi?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Logout", role: .destructive) { model.signOut() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .cardStyle()
    }
}

// MARK: - Rows

private struct NavigationRow<Destination: View>: View {
    let title: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title).foregroundStyle(SMA.labelPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelSecondary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

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
        .padding(16)
    }
}

// MARK: - Detail screens

struct PersonalInformationView: View {
    @State private var firstName = "Alex"
    @State private var lastName = "Morgan"
    @State private var email = "alex.morgan@example.com"
    @State private var phone = "(314) 555-0142"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                labeledField("First Name", text: $firstName)
                Divider().overlay(SMA.separator).padding(.leading, 16)
                labeledField("Last Name", text: $lastName)
                Divider().overlay(SMA.separator).padding(.leading, 16)
                labeledField("Email", text: $email)
                Divider().overlay(SMA.separator).padding(.leading, 16)
                labeledField("Phone", text: $phone)
            }
            .cardStyle()
            .padding(20)
        }
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle("Personal Information")
        .inlineNavTitle()
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(SMA.labelSecondary)
                .frame(width: 90, alignment: .leading)
            TextField(label, text: text)
                .foregroundStyle(SMA.labelPrimary)
        }
        .padding(16)
    }
}

struct NotificationSettingsView: View {
    @State private var smartAlerts = true
    @State private var energyReports = false
    @State private var offers = true
    @State private var deviceStatus = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                toggle("Smart Alerts", isOn: $smartAlerts)
                Divider().overlay(SMA.separator).padding(.leading, 16)
                toggle("Energy Reports", isOn: $energyReports)
                Divider().overlay(SMA.separator).padding(.leading, 16)
                toggle("Info & Offers", isOn: $offers)
                Divider().overlay(SMA.separator).padding(.leading, 16)
                toggle("Device Status", isOn: $deviceStatus)
            }
            .cardStyle()
            .padding(20)
        }
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle("Notification Settings")
        .inlineNavTitle()
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(Color(hex: 0x34C759))
            .foregroundStyle(SMA.labelPrimary)
            .padding(16)
    }
}

struct PlaceholderDetail: View {
    let title: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(SMA.labelSecondary)
            Text("\(title)")
                .font(.headline)
                .foregroundStyle(SMA.labelPrimary)
            Text("Prototype screen")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle(title)
        .inlineNavTitle()
    }
}

#Preview {
    AccountView()
        .environment(AppModel())
}
