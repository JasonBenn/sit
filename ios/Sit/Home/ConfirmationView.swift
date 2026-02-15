import SwiftUI

struct ConfirmationView: View {
    var onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Theme.sage.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(Theme.sageText)
                }
                .scaleEffect(scale)

                Text("Check-in saved")
                    .font(Theme.display(24))
                    .foregroundColor(Theme.text)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onDismiss()
            }
        }
    }
}
