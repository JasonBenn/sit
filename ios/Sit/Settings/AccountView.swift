import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var passwordMessage: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textMuted)
                        Text(authManager.user?.username ?? "")
                            .font(Theme.body(16))
                            .foregroundColor(Theme.text)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card)
                            .cornerRadius(12)
                    }

                    // Change Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Change Password")
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textMuted)

                        SecureField("Current password", text: $currentPassword)
                            .foregroundColor(Theme.text)
                            .padding()
                            .background(Theme.card)
                            .cornerRadius(12)

                        SecureField("New password", text: $newPassword)
                            .foregroundColor(Theme.text)
                            .padding()
                            .background(Theme.card)
                            .cornerRadius(12)

                        if let msg = passwordMessage {
                            Text(msg)
                                .font(Theme.body(12))
                                .foregroundColor(msg.contains("Updated") ? Theme.sageText : .red)
                        }

                        Button {
                            Task { await changePassword() }
                        } label: {
                            Text("Update Password")
                                .font(Theme.body(14, weight: .medium))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.sage)
                                .cornerRadius(12)
                        }
                        .disabled(currentPassword.isEmpty || newPassword.count < 6)
                    }

                    Spacer().frame(height: 32)

                    // Delete Account
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Account")
                            .font(Theme.body(14))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await APIService.shared.deleteAccount()
                    await MainActor.run { authManager.logout() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all data. This cannot be undone.")
        }
    }

    private func changePassword() async {
        do {
            try await APIService.shared.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            passwordMessage = "Updated!"
            currentPassword = ""
            newPassword = ""
        } catch {
            passwordMessage = "Failed. Check your current password."
        }
    }
}
