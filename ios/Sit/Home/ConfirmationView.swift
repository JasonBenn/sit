import SwiftUI

struct ConfirmationView: View {
    var onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("\u{2713}")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.sageText)
                    .opacity(0.9)

                VStack(spacing: 8) {
                    Text("Check-in saved")
                        .font(Theme.display(24))
                        .foregroundColor(Color(hex: "C0BDB6"))

                    Text("Returning home...")
                        .font(Theme.body(14))
                        .foregroundColor(Theme.textDim)
                }
            }
            .scaleEffect(scale)
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
