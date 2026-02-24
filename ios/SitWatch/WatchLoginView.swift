import SwiftUI

struct WatchLoginView: View {
    @EnvironmentObject var authManager: WatchAuthManager

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Sit")
                    .font(.headline)
                    .foregroundColor(.white)

                TextField("Username", text: $username)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(6)
                    .background(WatchTheme.card)
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(WatchTheme.card)
                    .cornerRadius(8)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    submitLogin()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .padding(.vertical, 8)
                .background(WatchTheme.amber)
                .cornerRadius(8)
            }
            .padding(.horizontal, 8)
        }
    }

    private func submitLogin() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.login(username: username, password: password)
            } catch APIError.serverError(let code, _) where code == 401 {
                errorMessage = "Invalid username or password"
            } catch {
                errorMessage = "Login failed"
            }
            isLoading = false
        }
    }
}

#Preview {
    WatchLoginView()
        .environmentObject(WatchAuthManager())
}
