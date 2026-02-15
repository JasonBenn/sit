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
                        Text("USERNAME")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)
                        Text(authManager.user?.username ?? "")
                            .font(Theme.body(16))
                            .foregroundColor(Theme.text)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card)
                            .cornerRadius(16)
                    }

                    // Security
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECURITY")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

                        SecureField("Current password", text: $currentPassword)
                            .foregroundColor(Theme.text)
                            .padding()
                            .background(Theme.card)
                            .cornerRadius(16)

                        SecureField("New password", text: $newPassword)
                            .foregroundColor(Theme.text)
                            .padding()
                            .background(Theme.card)
                            .cornerRadius(16)

                        if let msg = passwordMessage {
                            Text(msg)
                                .font(Theme.body(12))
                                .foregroundColor(msg.contains("Updated") ? Theme.sageText : .red)
                        }

                        Button {
                            Task { await changePassword() }
                        } label: {
                            Text("Change Password")
                                .font(Theme.body(14, weight: .medium))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.sage)
                                .cornerRadius(16)
                        }
                        .disabled(currentPassword.isEmpty || newPassword.count < 6)
                    }

                    Spacer().frame(height: 32)

                    // Danger Zone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DANGER ZONE")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Account")
                                .font(Theme.body(14))
                                .foregroundColor(Color(hex: "C08060"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.card)
                                .cornerRadius(16)
                        }

                        Text("This permanently deletes all your data")
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textDim)
                            .padding(.leading, 4)
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
