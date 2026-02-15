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
                Text("STEP \(stepNumber) OF \(totalSteps)")
                    .font(Theme.body(11))
                    .foregroundColor(Theme.textDim)
                    .tracking(1)

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
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(buttonColor(for: index))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func buttonColor(for index: Int) -> Color {
        switch index {
        case 0: return Theme.sage
        case 1: return Theme.amber
        default: return Theme.card
        }
    }
}
