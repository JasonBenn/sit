import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(number: Int, title: String, description: String)] = [
        (1, "You'll get nudged throughout the day",
         "Notifications ask a simple question: are you in the View right now? You can set how many per day."),
        (2, "Check in from your Watch or iPhone",
         "Tap a notification to open a short check-in flow. Answer honestly — yes or no — and follow the prompts. Takes about 10 seconds."),
        (3, "Record a voice note if you want",
         "Some prompts offer a voice note option. Speak freely about what you're noticing. These get transcribed and stored."),
        (4, "Ask about your practice anytime",
         "Use the chat on the home screen to ask questions about your check-in history, patterns, and progress over time."),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Brand
                    Text("Sit")
                        .font(Theme.display(40, weight: .light))
                        .foregroundColor(Theme.text)
                        .padding(.top, 48)

                    Text("A practice companion")
                        .font(Theme.display(16))
                        .foregroundColor(Theme.textDim)
                        .italic()
                        .padding(.top, 4)
                        .padding(.bottom, 40)

                    // Steps
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(steps, id: \.number) { step in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.sage)
                                        .frame(width: 32, height: 32)

                                    Text("\(step.number)")
                                        .font(Theme.body(14, weight: .medium))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(Theme.body(14, weight: .medium))
                                        .foregroundColor(Theme.text)

                                    Text(step.description)
                                        .font(Theme.body(14))
                                        .foregroundColor(Theme.textDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Customize hint
                    Text("You can customize your check-in flow and explore flows from others in Settings.")
                        .font(Theme.body(14))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.sage.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.sage.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 40)

                    // CTA
                    Button {
                        Task {
                            try? await APIService.shared.markOnboardingSeen()
                        }
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .font(Theme.body(16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.sage)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Feedback
                    HStack(spacing: 0) {
                        Text("Feedback? ")
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textDim)
                        Link("Email Jason Benn", destination: URL(string: "mailto:jasoncbenn@gmail.com")!)
                            .font(Theme.body(12))
                            .foregroundColor(Theme.textDim)
                            .underline()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}
