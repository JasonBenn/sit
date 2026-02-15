import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(Theme.body(15))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Theme.sage.opacity(0.3) : Theme.card)
                    .cornerRadius(16)

                if let createdAt = message.createdAt {
                    Text(createdAt)
                        .font(Theme.body(11))
                        .foregroundColor(Theme.textDim)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
