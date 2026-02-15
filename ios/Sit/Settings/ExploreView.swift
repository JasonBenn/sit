import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var flows: [PublicFlow] = []
    @State private var expandedId: String?
    @State private var showUseConfirm = false
    @State private var selectedUsername: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                if flows.isEmpty {
                    Text("No public flows yet")
                        .font(Theme.body(14))
                        .foregroundColor(Theme.textMuted)
                        .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(flows) { flow in
                            flowCard(flow)
                        }
                    }
                    .padding(16)
                }
            }

            if showSuccess {
                VStack {
                    Spacer()
                    Text("Flow adopted!")
                        .font(Theme.body(14, weight: .medium))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.sage)
                        .cornerRadius(20)
                        .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSuccess = false }
                    }
                }
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadFlows() }
        .alert("Use this flow?", isPresented: $showUseConfirm) {
            Button("Use Flow") {
                if let username = selectedUsername {
                    Task { await adoptFlow(username: username) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace your current check-in flow.")
        }
    }

    private func flowCard(_ flow: PublicFlow) -> some View {
        let isExpanded = expandedId == flow.id
        let isCurrentUser = flow.username == authManager.user?.username

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation { expandedId = isExpanded ? nil : flow.id }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(flow.flowName)
                                .font(Theme.body(16, weight: .medium))
                                .foregroundColor(Theme.text)
                            if isCurrentUser {
                                Text("Your flow")
                                    .font(Theme.body(10))
                                    .foregroundColor(Theme.sageText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Theme.sage.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        Text("by \(flow.username) \u{00B7} \(flow.stepCount) steps")
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.textDim)
                        .font(.system(size: 12))
                }
                .padding(16)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if !flow.description.isEmpty {
                        Text(flow.description)
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)
                    }

                    // Steps preview
                    ForEach(flow.stepsJson) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(step.id)")
                                .font(Theme.body(11))
                                .foregroundColor(Theme.textDim)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(Theme.body(13, weight: .medium))
                                    .foregroundColor(Theme.text)
                                ForEach(step.answers) { answer in
                                    let dest: String = {
                                        switch answer.destination {
                                        case .step(let id): return "-> Step \(id)"
                                        case .submit: return "-> Submit"
                                        }
                                    }()
                                    Text("\(answer.label) \(dest)")
                                        .font(Theme.body(11))
                                        .foregroundColor(Theme.textDim)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        NavigationLink {
                            FlowPreviewView(flow: flow.toFlowDefinition())
                        } label: {
                            Text("Preview")
                                .font(Theme.body(14, weight: .medium))
                                .foregroundColor(Theme.sageText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.sage.opacity(0.2))
                                .cornerRadius(10)
                        }

                        if !isCurrentUser {
                            Button {
                                selectedUsername = flow.username
                                showUseConfirm = true
                            } label: {
                                Text("Use This Flow")
                                    .font(Theme.body(14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.sage)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Theme.card)
        .cornerRadius(12)
    }

    private func loadFlows() async {
        flows = (try? await APIService.shared.getPublicFlows()) ?? []
    }

    private func adoptFlow(username: String) async {
        _ = try? await APIService.shared.useFlow(username: username)
        await authManager.refreshUser()
        withAnimation { showSuccess = true }
    }
}

