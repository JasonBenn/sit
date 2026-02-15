import SwiftUI

struct ConversationStartersView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var starters: [String] = []

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Shown on the home screen below Check In. Tapping one starts a chat with that question.")
                        .font(Theme.body(13))
                        .foregroundColor(Theme.textDim)
                        .padding(.horizontal, 4)

                    ForEach(starters.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 0) {
                            // Header row
                            HStack {
                                Text("Starter \(index + 1)")
                                    .font(Theme.body(12, weight: .medium))
                                    .foregroundColor(Theme.textMuted)
                                Spacer()
                                Button {
                                    starters.remove(at: index)
                                    save()
                                } label: {
                                    Text("Remove")
                                        .font(Theme.body(12))
                                        .foregroundColor(Color(hex: "C08060"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                            // Text field in sub-card
                            TextField("Conversation starter", text: $starters[index])
                                .font(Theme.body(14))
                                .foregroundColor(Theme.text)
                                .padding(12)
                                .background(Theme.cardAlt)
                                .cornerRadius(10)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                                .onChange(of: starters[index]) { save() }
                        }
                        .background(Theme.card)
                        .cornerRadius(16)
                    }

                    // Add Starter button
                    Button {
                        starters.append("")
                    } label: {
                        Text("+ Add Starter")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.sageText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                                    .foregroundColor(Theme.border)
                            )
                    }

                    Spacer()
                }
                .padding(16)
            }
        }
        .navigationTitle("Conversation Starters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            starters = authManager.user?.conversationStarters ?? []
        }
    }

    private func save() {
        let nonEmpty = starters.filter { !$0.isEmpty }
        Task {
            try? await APIService.shared.updateConversationStarters(nonEmpty)
            await authManager.refreshUser()
        }
    }
}
