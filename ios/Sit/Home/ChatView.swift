import SwiftUI

struct ChatView: View {
    var initialMessage: String?

    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

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
                    TextField("Ask anything...", text: $viewModel.inputText)
                        .font(Theme.body(14))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.card)
                        .clipShape(Capsule())
                        .focused($isInputFocused)

                    Button {
                        isInputFocused = false
                        Task { await viewModel.sendMessage() }
                    } label: {
                        Text("\u{2191}")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Theme.sage)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
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
