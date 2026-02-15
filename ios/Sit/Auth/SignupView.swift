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

            VStack(spacing: 32) {
                Spacer()

                Text("Create Account")
                    .font(Theme.display(36))
                    .foregroundColor(Theme.text)

                VStack(spacing: 16) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Theme.card)
                        .foregroundColor(Theme.text)
                        .cornerRadius(12)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Theme.card)
                        .foregroundColor(Theme.text)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.body(14))
                        .foregroundColor(.red)
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
                                .font(Theme.body(16, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.sage)
                    .foregroundColor(Theme.text)
                    .cornerRadius(12)
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    showSignup = false
                } label: {
                    Text("Already have an account? ")
                        .foregroundColor(Theme.textMuted) +
                    Text("Log In")
                        .foregroundColor(Theme.sageText)
                }
                .font(Theme.body(14))

                Text("Questions? jason@jasonbenn.com")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.textDim)
                    .padding(.bottom, 16)
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
