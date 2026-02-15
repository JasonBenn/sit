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
                            .textContentType(.password)
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
                    Task { await login() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(Theme.text)
                        } else {
                            Text("Log In")
                                .font(Theme.body(18, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.sage)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                Button {
                    showSignup = true
                } label: {
                    Text("Don't have an account? ")
                        .foregroundColor(Theme.textMuted) +
                    Text("Sign Up")
                        .foregroundColor(Theme.sageText)
                }
                .font(Theme.body(14))

                Spacer()

                Link(destination: URL(string: "mailto:jasoncbenn@gmail.com")!) {
                    (Text("Feedback? ")
                        .foregroundColor(Theme.textDim) +
                    Text("Email Jason Benn")
                        .foregroundColor(Theme.textDim)
                        .underline())
                }
                .font(Theme.body(12))
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
