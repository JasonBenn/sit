import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var showSignup: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("Sit")
                    .font(Theme.display(56, weight: .light))
                    .tracking(2)
                    .foregroundColor(Theme.text)
                    .padding(.bottom, 48)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.textMuted)
                            .padding(.leading, 4)
                        TextField("", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.card)
                            .foregroundColor(Theme.text)
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.textMuted)
                            .padding(.leading, 4)
                        SecureField("", text: $password)
                            .textContentType(.newPassword)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.card)
                            .foregroundColor(Theme.text)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.body(14))
                        .foregroundColor(.red)
                        .padding(.bottom, 16)
                }

                Button {
                    Task { await signup() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(Theme.text)
                        } else {
                            Text("Sign Up")
                                .font(Theme.body(18, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.sage)
                    .foregroundColor(Theme.text)
                    .cornerRadius(12)
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                Button {
                    showSignup = false
                } label: {
                    Text("Already have an account? ")
                        .foregroundColor(Theme.textMuted) +
                    Text("Log In")
                        .foregroundColor(Theme.sageText)
                }
                .font(Theme.body(14))

                Spacer()
            }
        }
    }

    private func signup() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signup(username: username, password: password)
        } catch {
            errorMessage = "Signup failed. Username may be taken."
        }
        isLoading = false
    }
}
