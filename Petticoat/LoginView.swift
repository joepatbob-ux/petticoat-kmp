import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                } footer: {
                    HStack {
                        Spacer()
                        NavigationLink("Forgot Password?") {
                            ForgotPasswordView()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SMA.accent)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .safeAreaInset(edge: .top) {
                Image("SensiByCopeland")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    // Inset 16pt beyond the form's 20pt card margins on each side,
                    // trimming the logo 32pt narrower than the fields below it.
                    .padding(.horizontal, 36)
                    .accessibilityLabel("Sensi by Copeland")
                    .padding(.top, 24)
                    .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    NavigationLink("Create Account") {
                        CreateAccountView()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SMA.accent)

                    Button {
                        model.signIn()
                    } label: {
                        Text("Login")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(SMA.accent)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 8)
            }
            .readableFormWidth()
            .background(SMA.groupedBackground.ignoresSafeArea())
        }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showConfirmation = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            } footer: {
                Text("To receive a new password, please enter the email address associated with your account.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .readableFormWidth()
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle("Forgot Password")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showConfirmation = true
                } label: {
                    Image(systemName: "arrow.up")
                }
                .accessibilityLabel("Reset Password")
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(SMA.accent)
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty)
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
        Form {
            Section {
                field("First Name", text: $firstName)
                field("Last Name", text: $lastName)
                field("Phone", text: $phone)
                field("Email", text: $email)
                SecureField("Password", text: $password)
            } footer: {
                Text("By creating a Sensi account, you agree to Terms of Service, End User License Agreement, and Privacy Policy.")
            }

            Section {
                toggleRow("Smart Alerts",
                          detail: "Know when there may be an issue with your HVAC system with help from Smart Alerts.",
                          isOn: $smartAlerts)
                toggleRow("Sensi Info & Offers",
                          detail: "Stay informed about local utility rebates, monthly usage reports, energy-saving tips, and new products.",
                          isOn: $infoOffers)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .readableFormWidth()
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle("Create Account")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.signIn()
                } label: {
                    Image(systemName: "arrow.up")
                }
                .accessibilityLabel("Create Account")
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(SMA.accent)
                .disabled(!isFormComplete)
            }
        }
    }

    /// The submit button stays disabled until every field has content.
    private var isFormComplete: Bool {
        [firstName, lastName, phone, email, password]
            .allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(placeholder == "Email" ? .never : .words)
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary)
            }
        }
        .tint(Color(hex: 0x34C759))
    }
}

#Preview {
    LoginView()
        .environment(AppModel())
}
