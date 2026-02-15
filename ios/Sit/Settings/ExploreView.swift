import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var flows: [PublicFlow] = []
    @State private var expandedId: String?
    @State private var showUseConfirm = false
    @State private var selectedFlow: PublicFlow?
    @State private var showSuccess = false
    @State private var adoptedFlowName: String = ""

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
                        Text("PUBLIC FLOWS FROM ALL USERS")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)
                            .padding(.bottom, 4)

                        ForEach(flows) { flow in
                            flowCard(flow)
                        }
                    }
                    .padding(16)
                }
            }

            if showSuccess {
                VStack {
                    HStack(spacing: 12) {
                        Text("\u{2713}")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.sageText)
                        Text("Now using '\(adoptedFlowName)'!")
                            .font(Theme.body(14, weight: .medium))
                            .foregroundColor(Theme.sageText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.sage.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Theme.sage.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top))
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
        .alert(
            "Replace '\(authManager.user?.currentFlow?.name ?? "your flow")' with '\(selectedFlow?.flowName ?? "")'?",
            isPresented: $showUseConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) {
                if let flow = selectedFlow {
                    Task { await adoptFlow(username: flow.username) }
                }
            }
        } message: {
            Text("Your edits will be lost. This can't be undone.")
        }
    }

    private func flowCard(_ flow: PublicFlow) -> some View {
        let isExpanded = expandedId == flow.id
        let isCurrentUser = flow.username == authManager.user?.username

        return VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            Button {
                withAnimation { expandedId = isExpanded ? nil : flow.id }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(flow.flowName)
                                .font(Theme.body(14, weight: .medium))
                                .foregroundColor(Theme.text)
                            if isCurrentUser {
                                Text("Your flow")
                                    .font(Theme.body(10))
                                    .foregroundColor(Theme.sageText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.sage.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        Text("by \(flow.username) \u{00B7} \(flow.stepCount) steps")
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textDim)
                        if !flow.description.isEmpty {
                            Text(flow.description)
                                .font(Theme.body(12))
                                .foregroundColor(Theme.textDim)
                                .opacity(0.7)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    if !isCurrentUser {
                        Button {
                            selectedFlow = flow
                            showUseConfirm = true
                        } label: {
                            Text("Use")
                                .font(Theme.body(12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.sage)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Theme.border)

                    ForEach(flow.stepsJson) { step in
                        let stepIndex = (flow.stepsJson.firstIndex(where: { $0.id == step.id }).map({ $0 + 1 })) ?? step.id
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Step \(stepIndex) \u{2013} \(step.title)")
                                .font(Theme.body(12, weight: .medium))
                                .foregroundColor(Theme.sageText)
                            Text(step.prompt)
                                .font(Theme.body(12))
                                .foregroundColor(Theme.textMuted)
                            HStack(spacing: 6) {
                                ForEach(step.answers, id: \.label) { answer in
                                    let dest: String = {
                                        switch answer.destination {
                                        case .step(let id):
                                            let target = flow.stepsJson.first(where: { $0.id == id })
                                            return "\(answer.label) \u{2192} \(target?.title ?? "Step \(id)")"
                                        case .submit:
                                            return "\(answer.label) \u{2192} Submit"
                                        }
                                    }()
                                    let bgColor: Color = answer.recordVoiceNote
                                        ? Color(red: 140/255, green: 110/255, blue: 170/255).opacity(0.12)
                                        : Theme.sage.opacity(0.15)
                                    let txtColor: Color = answer.recordVoiceNote
                                        ? Color(hex: "B8A0D0")
                                        : Theme.sageText
                                    Text(dest)
                                        .font(Theme.body(10))
                                        .foregroundColor(txtColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(bgColor)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(12)
                        .background(Theme.cardAlt)
                        .cornerRadius(12)
                    }

                    // Preview button
                    NavigationLink {
                        FlowPreviewView(flow: flow.toFlowDefinition())
                    } label: {
                        HStack(spacing: 6) {
                            Text("\u{25B6}")
                                .foregroundColor(Color(hex: "7BA085"))
                            Text("Preview Flow")
                                .font(Theme.body(12, weight: .medium))
                                .foregroundColor(Color(hex: "7BA085"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.cardAlt)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isExpanded ? Theme.sage.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func loadFlows() async {
        flows = (try? await APIService.shared.getPublicFlows()) ?? []
    }

    private func adoptFlow(username: String) async {
        if let flow = selectedFlow {
            adoptedFlowName = flow.flowName
        }
        _ = try? await APIService.shared.useFlow(username: username)
        await authManager.refreshUser()
        withAnimation { showSuccess = true }
    }
}
