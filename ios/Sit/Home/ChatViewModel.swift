import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading = false

    func loadHistory() async {
        messages = (try? await APIService.shared.getChatHistory()) ?? []
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(id: UUID().uuidString, role: "user", content: text, createdAt: nil)
        messages.append(userMsg)
        inputText = ""
        isLoading = true

        let response = try? await APIService.shared.sendChatMessage(text)
        if let response {
            messages.append(response)
        } else {
            messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", content: "Sorry, something went wrong.", createdAt: nil))
        }
        isLoading = false
    }

    func sendInitialMessage(_ text: String) async {
        inputText = text
        await sendMessage()
    }
}
