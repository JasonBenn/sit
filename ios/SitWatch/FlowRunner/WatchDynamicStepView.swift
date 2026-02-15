import SwiftUI
import WatchKit

struct WatchDynamicStepView: View {
    let step: FlowStep
    let onAnswer: (FlowAnswer, Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(step.prompt)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(WatchTheme.text)
                    .padding(.top, 4)

                ForEach(Array(step.answers.enumerated()), id: \.element.label) { index, answer in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        onAnswer(answer, index)
                    } label: {
                        Text(answer.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(WatchTheme.sageText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(WatchTheme.sage.opacity(0.25))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    WatchDynamicStepView(
        step: FlowStep(id: 0, title: "Test", prompt: "Are you in the View?", answers: [
            FlowAnswer(label: "Yes", destination: .step(1), recordVoiceNote: false),
            FlowAnswer(label: "No", destination: .step(2), recordVoiceNote: false)
        ]),
        onAnswer: { _, _ in }
    )
}
