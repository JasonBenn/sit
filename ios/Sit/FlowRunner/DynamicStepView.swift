import SwiftUI

struct DynamicStepView: View {
    let step: FlowStep
    let stepNumber: Int
    let totalSteps: Int
    var onAnswer: (Int) -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Step \(stepNumber) of \(totalSteps)")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.textMuted)

                Text(step.prompt)
                    .font(Theme.display(28))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                ForEach(Array(step.answers.enumerated()), id: \.offset) { index, answer in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onAnswer(index)
                    } label: {
                        Text(answer.label)
                            .font(Theme.body(16))
                            .foregroundColor(index == 0 ? Theme.sageText : Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(index == 0 ? Theme.sage.opacity(0.3) : Theme.card)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
