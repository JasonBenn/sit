import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showOnboarding = false

    private var flow: FlowDefinition? { authManager.user?.currentFlow }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    settingsRow("Notifications", subtitle: notificationSubtitle) {
                        NotificationSettingsView()
                    }

                    settingsRow("Edit Watch Check-In Flow", subtitle: flowSubtitle) {
                        FlowEditorView()
                    }

                    settingsRow("Conversation Starters", subtitle: startersSubtitle) {
                        ConversationStartersView()
                    }

                    settingsRow("Explore", subtitle: "Check-in flows from the sangha") {
                        ExploreView()
                    }

                    settingsRow("Account", subtitle: authManager.user?.username) {
                        AccountView()
                    }

                    // Log Out
                    Button {
                        authManager.logout()
                    } label: {
                        Text("Log Out")
                            .font(Theme.body(14))
                            .foregroundColor(Color(hex: "C08060"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.card)
                            .cornerRadius(16)
                    }
                    .padding(.top, 20)

                    // Feedback email
                    Link(destination: URL(string: "mailto:jasoncbenn@gmail.com")!) {
                        (Text("Feedback? ")
                            .foregroundColor(Theme.textDim) +
                        Text("Email Jason Benn")
                            .foregroundColor(Theme.textDim)
                            .underline())
                    }
                    .font(Theme.body(12))
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showOnboarding = true } label: {
                    Text("?")
                        .font(Theme.body(12, weight: .medium))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 28, height: 28)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }

    private var notificationSubtitle: String {
        let count = authManager.user?.notificationCount ?? 3
        let start = formatHour(authManager.user?.notificationStartHour ?? 9)
        let end = formatHour(authManager.user?.notificationEndHour ?? 22)
        return "\(count) per day, \(start)\u{2013}\(end)"
    }

    private var flowSubtitle: String? {
        guard let flow = flow else { return nil }
        return "\(flow.name) \u{00B7} \(flow.stepsJson.count) steps"
    }

    private var startersSubtitle: String {
        let count = authManager.user?.conversationStarters?.count ?? 0
        return "\(count) prompts on home screen"
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h)\(ampm)"
    }

    private func settingsRow<Destination: View>(_ title: String, subtitle: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.body(14, weight: .medium))
                        .foregroundColor(Theme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textDim)
                    }
                }
                Spacer()
                Text("\u{203A}")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Theme.card)
            .cornerRadius(16)
        }
    }
}
