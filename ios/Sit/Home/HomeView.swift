import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var chatInput = ""
    @State private var showOnboarding = false
    @State private var showFlow = false
    @State private var navigateToChat = false
    @State private var initialChatMessage: String?

    private var currentFlow: FlowDefinition? {
        authManager.user?.currentFlow
    }

    private var starters: [String] {
        authManager.user?.conversationStarters ?? [
            "What patterns do you see in my practice?",
            "How often have I been checking in?",
            "What's my relationship with the View like lately?"
        ]
    }

    private var shouldShowOnboarding: Bool {
        authManager.user?.hasSeenOnboarding == false
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Sit")
                        .font(Theme.display(32))
                        .foregroundColor(Theme.text)

                    Spacer()

                    Button { showOnboarding = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textMuted)
                    }

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Check In circle
                Button { showFlow = true } label: {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .strokeBorder(Theme.sage, lineWidth: 2)
                                .frame(width: 160, height: 160)

                            Text("Check In")
                                .font(Theme.display(24))
                                .foregroundColor(Theme.sageText)
                        }

                        if let flow = currentFlow {
                            Text(flow.name)
                                .font(Theme.body(14))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                }

                Spacer()

                // Conversation starters
                VStack(spacing: 8) {
                    ForEach(starters, id: \.self) { starter in
                        Button {
                            initialChatMessage = starter
                            navigateToChat = true
                        } label: {
                            Text(starter)
                                .font(Theme.body(14))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.card)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Chat input
                HStack(spacing: 12) {
                    TextField("Ask about your practice...", text: $chatInput)
                        .font(Theme.body(14))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.card)
                        .cornerRadius(12)

                    if !chatInput.isEmpty {
                        Button {
                            initialChatMessage = chatInput
                            chatInput = ""
                            navigateToChat = true
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.sage)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToChat) {
            ChatView(initialMessage: initialChatMessage)
        }
        .fullScreenCover(isPresented: $showFlow) {
            if let flow = currentFlow {
                DynamicFlowView(flow: flow, isPreview: false) {
                    showFlow = false
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            if shouldShowOnboarding {
                showOnboarding = true
            }
        }
        .task {
            await authManager.refreshUser()
        }
    }
}

