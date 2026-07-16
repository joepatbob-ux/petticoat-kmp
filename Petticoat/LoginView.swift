import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                SensiLockup(
                    wordmarkColor: SMA.brandBlue,
                    copelandColor: SMA.brandNavy,
                    size: 56
                )
                .padding(.bottom, 32)

                // Email + password
                VStack(spacing: 0) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, 14)
                    Divider().overlay(SMA.separator)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 16)
                .cardStyle()
                .padding(.horizontal, 20)

                HStack {
                    Spacer()
                    NavigationLink("Forgot Password?") {
                        ForgotPasswordView()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.accent)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)

                Spacer()

                NavigationLink("Create Account") {
                    CreateAccountView()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(SMA.accent)
                .padding(.bottom, 20)

                Button {
                    model.signIn()
                } label: {
                    Text("Login")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(SMA.accent, in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(Color.white)
        }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .cardStyle()

            Text("To receive a new password, please enter the email address associated with your account.")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
                .padding(.horizontal, 4)

            Spacer()
        }
        .padding(20)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle("Forgot Password")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showConfirmation = true
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(SMA.accent, in: Circle())
                }
            }
        }
        .alert("Password Reset", isPresented: $showConfirmation) {
            Button("Return to Login") { dismiss() }
        } message: {
            Text("A temporary password was sent to your email.")
        }
    }
}

// MARK: - Create Account

struct CreateAccountView: View {
    @Environment(AppModel.self) private var model
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""
    @State private var smartAlerts = true
    @State private var infoOffers = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    field("First Name", text: $firstName)
                    Divider().overlay(SMA.separator)
                    field("Last Name", text: $lastName)
                    Divider().overlay(SMA.separator)
                    field("Phone", text: $phone)
                    Divider().overlay(SMA.separator)
                    field("Email", text: $email)
                    Divider().overlay(SMA.separator)
                    SecureField("Password", text: $password)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                .cardStyle()

                Text("By creating a Sensi account, you agree to Terms of Service, End User License Agreement, and Privacy Policy.")
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                toggleRow("Smart Alerts",
                          detail: "Know when there may be an issue with your HVAC system with help from Smart Alerts.",
                          isOn: $smartAlerts)
                toggleRow("Sensi Info & Offers",
                          detail: "Stay informed about local utility rebates, monthly usage reports, energy-saving tips, and new products.",
                          isOn: $infoOffers)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Create Account")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.signIn()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(SMA.accent, in: Circle())
                }
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(placeholder == "Email" ? .never : .words)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: isOn)
                .font(.body)
                .tint(Color(hex: 0x34C759))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LoginView()
        .environment(AppModel())
}
