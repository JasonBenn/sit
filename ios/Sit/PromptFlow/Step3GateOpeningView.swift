import SwiftUI

struct Step3GateOpeningView: View {
    var onWorked: () -> Void
    var onDidntWork: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "door.left.hand.open")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Open through the gate of the ears. No inside and no outside? Can you see through the agent - the illusion that this feeling of center is the cause of your thoughts - or through the idea that the agent's efforts are required?")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 16) {
                Button(action: onWorked) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.headline)
                        Text("It worked")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)

                Button(action: onDidntWork) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .font(.headline)
                        Text("It didn't work")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.orange)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

#Preview {
    Step3GateOpeningView(onWorked: {}, onDidntWork: {})
}
