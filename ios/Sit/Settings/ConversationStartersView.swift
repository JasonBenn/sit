import SwiftUI

struct ConversationStartersView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var starters: [String] = []

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 12) {
                ForEach(starters.indices, id: \.self) { index in
                    HStack {
                        TextField("Conversation starter", text: $starters[index])
                            .font(Theme.body(14))
                            .foregroundColor(Theme.text)
                            .padding()
                            .background(Theme.card)
                            .cornerRadius(12)
                            .onChange(of: starters[index]) { save() }

                        Button {
                            starters.remove(at: index)
                            save()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }

                Button {
                    starters.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.sage)
                        Text("Add Starter")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.sageText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding(16)
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
