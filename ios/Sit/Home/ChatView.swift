import SwiftUI

struct ChatView: View {
    var initialMessage: String?

    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(Theme.textMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .id("loading")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                HStack(spacing: 12) {
                    TextField("Message...", text: $viewModel.inputText)
                        .font(Theme.body(14))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.card)
                        .cornerRadius(12)

                    if !viewModel.inputText.isEmpty {
                        Button {
                            Task { await viewModel.sendMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.sage)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.bg)
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadHistory()
            if let initial = initialMessage {
                await viewModel.sendInitialMessage(initial)
            }
        }
    }
}
