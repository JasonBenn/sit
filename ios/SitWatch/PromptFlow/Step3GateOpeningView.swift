import SwiftUI

struct Step3GateOpeningView: View {
    var onWorked: () -> Void
    var onDidntWork: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Gate icon
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                    .padding(.top, 8)

                Text("Open through the gate of the ears. No inside and no outside? Can you see through the agent - the illusion that this feeling of center is the cause of your thoughts - or through the idea that the agent's efforts are required?")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                VStack(spacing: 10) {
                    Button(action: onWorked) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("It worked")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDidntWork) {
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption)
                            Text("It didn't work")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
            }
            .padding()
        }
    }
}

#Preview {
    Step3GateOpeningView(onWorked: {}, onDidntWork: {})
}
