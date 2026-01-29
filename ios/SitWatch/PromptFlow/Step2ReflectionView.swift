import SwiftUI

struct Step2ReflectionView: View {
    var onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Smiley indicator
                Image(systemName: "face.smiling")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
                    .padding(.top, 8)

                Text("How are you relating to things? With compassion?")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text("Are you seeing them as sacred?")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("Right conduct is intention & result: do you intend to be of service?")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                Button(action: onComplete) {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.caption)
                        Text("Got it")
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
                .padding(.horizontal, 16)
            }
            .padding()
        }
    }
}

#Preview {
    Step2ReflectionView(onComplete: {})
}
