import SwiftUI

struct Step2ReflectionView: View {
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "face.smiling")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 16) {
                Text("How are you relating to things? With compassion?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text("Are you seeing them as sacred?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("Right conduct is intention & result: do you intend to be of service?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark")
                        .font(.headline)
                    Text("Got it")
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
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

#Preview {
    Step2ReflectionView(onComplete: {})
}
