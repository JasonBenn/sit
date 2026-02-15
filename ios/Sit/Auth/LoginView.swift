import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSignup = false

    var body: some View {
        if showSignup {
            SignupView(showSignup: $showSignup)
        } else {
            loginContent
        }
    }

    private var loginContent: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("Sit")
                    .font(Theme.display(48))
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
                        .textContentType(.password)
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
                    Task { await login() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(Theme.text)
                        } else {
                            Text("Log In")
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
                    showSignup = true
                } label: {
                    Text("Don't have an account? ")
                        .foregroundColor(Theme.textMuted) +
                    Text("Sign Up")
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

    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.login(username: username, password: password)
        } catch {
            errorMessage = "Invalid username or password"
        }
        isLoading = false
    }
}
