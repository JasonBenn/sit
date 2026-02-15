import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(Theme.body(14))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color(hex: "4A6B50") : Theme.card)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: isUser ? 16 : 6,
                        bottomTrailingRadius: isUser ? 6 : 16,
                        topTrailingRadius: 16
                    ))

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
