import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps = [
        (number: 1, text: "Throughout the day, you'll get gentle reminders to check in"),
        (number: 2, text: "Each check-in is a brief meditation flow — just a few taps"),
        (number: 3, text: "You can customize your flow, record voice notes, and explore others' flows"),
        (number: 4, text: "Over time, an AI assistant helps you notice patterns in your practice"),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Welcome to Sit")
                    .font(Theme.display(28))
                    .foregroundColor(Theme.text)
                    .padding(.top, 48)

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Theme.sage.opacity(0.2))
                                    .frame(width: 36, height: 36)

                                Text("\(step.number)")
                                    .font(Theme.body(16))
                                    .foregroundColor(Theme.sageText)
                            }

                            Text(step.text)
                                .font(Theme.body(16))
                                .foregroundColor(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    Task {
                        try? await APIService.shared.markOnboardingSeen()
                    }
                    dismiss()
                } label: {
                    Text("Get Started")
                        .font(Theme.body(16))
                        .foregroundColor(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.sage)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
