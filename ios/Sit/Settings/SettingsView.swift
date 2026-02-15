import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Flow
                    settingsSection("Flow") {
                        settingsRow("Edit Watch Check-In Flow", subtitle: authManager.user?.currentFlow?.name ?? "Default") {
                            FlowEditorView()
                        }
                    }

                    // Preferences
                    settingsSection("Preferences") {
                        settingsRow("Notifications", subtitle: "\(authManager.user?.notificationCount ?? 3) per day") {
                            NotificationSettingsView()
                        }
                        settingsRow("Conversation Starters") {
                            ConversationStartersView()
                        }
                    }

                    // Discover
                    settingsSection("Discover") {
                        settingsRow("Explore Flows") {
                            ExploreView()
                        }
                    }

                    // Account
                    settingsSection("Account") {
                        settingsRow("Account") {
                            AccountView()
                        }
                    }

                    // Log Out
                    Button {
                        authManager.logout()
                    } label: {
                        Text("Log Out")
                            .font(Theme.body(16))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.card)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)

                    // Footer
                    VStack(spacing: 12) {
                        Button { showOnboarding = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 14))
                                Text("How Sit Works")
                                    .font(Theme.body(13))
                            }
                            .foregroundColor(Theme.textMuted)
                        }

                        Link("Feedback: jason@jasonbenn.com", destination: URL(string: "mailto:jason@jasonbenn.com")!)
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textDim)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(Theme.body(11))
                .foregroundColor(Theme.textDim)
                .padding(.leading, 4)
                .padding(.bottom, 4)
            content()
        }
    }

    private func settingsRow<Destination: View>(_ title: String, subtitle: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.body(16))
                        .foregroundColor(Theme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.card)
            .cornerRadius(12)
        }
    }
}

