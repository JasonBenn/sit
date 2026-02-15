import SwiftUI
import WatchKit

struct WatchDynamicFlowView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @StateObject private var queue = ResponseQueue.shared
    @State private var currentStepId: Int = 0
    @State private var collectedSteps: [[Int]] = []
    @State private var showConfirmation = false
    @State private var wasQueued = false
    @State private var isSubmitting = false
    @State private var voiceNoteURL: URL?
    @State private var voiceNoteDuration: Double?

    private var flow: FlowDefinition? {
        connectivity.currentFlow ?? Self.defaultFlow
    }

    private var currentStep: FlowStep? {
        flow?.stepsJson.first { $0.id == currentStepId }
    }

    var body: some View {
        Group {
            if let step = currentStep, let flow = flow {
                if step.answers.first(where: { $0.recordVoiceNote })?.recordVoiceNote == true {
                    WatchVoiceRecorderView(
                        prompt: step.prompt,
                        onSave: { duration, url in
                            voiceNoteDuration = duration
                            voiceNoteURL = url
                            collectedSteps.append([step.id, -1])
                            submitFlow(flow: flow)
                        },
                        onSkip: {
                            collectedSteps.append([step.id, -2])
                            submitFlow(flow: flow)
                        }
                    )
                } else {
                    WatchDynamicStepView(step: step) { answer, answerIndex in
                        collectedSteps.append([step.id, answerIndex])
                        switch answer.destination {
                        case .step(let nextId):
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStepId = nextId
                            }
                        case .submit:
                            submitFlow(flow: flow)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("No flow available")
                        .font(.caption2)
                        .foregroundColor(WatchTheme.textMuted)
                }
            }
        }
        .overlay {
            if isSubmitting {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .fullScreenCover(isPresented: $showConfirmation) {
            WatchConfirmationView(wasQueued: wasQueued)
        }
        .onAppear {
            if let flow = flow, let firstStep = flow.stepsJson.first {
                currentStepId = firstStep.id
            }
        }
    }

    private func submitFlow(flow: FlowDefinition) {
        isSubmitting = true
        Task {
            let sentImmediately = await queue.submit(
                flowId: flow.id,
                steps: collectedSteps,
                voiceNoteDuration: voiceNoteDuration,
                voiceNoteURL: voiceNoteURL
            )

            await MainActor.run {
                isSubmitting = false
                wasQueued = !sentImmediately
                WKInterfaceDevice.current().play(sentImmediately ? .success : .click)
                showConfirmation = true
            }
        }
    }

    // Fallback flow when no flow is synced from iPhone
    static let defaultFlow = FlowDefinition(
        id: "default",
        userId: nil,
        name: "Check In",
        description: "Quick meditation check-in",
        stepsJson: [
            FlowStep(id: 0, title: "Check In", prompt: "Are you in the View?", answers: [
                FlowAnswer(label: "Yes", destination: .step(1), recordVoiceNote: false),
                FlowAnswer(label: "No", destination: .step(2), recordVoiceNote: false)
            ]),
            FlowStep(id: 1, title: "Reflection", prompt: "Notice what's here.", answers: [
                FlowAnswer(label: "Done", destination: .submit, recordVoiceNote: false)
            ]),
            FlowStep(id: 2, title: "Gate Opening", prompt: "Take a breath.\nCan you find the View?", answers: [
                FlowAnswer(label: "Yes", destination: .step(1), recordVoiceNote: false),
                FlowAnswer(label: "No", destination: .step(3), recordVoiceNote: false)
            ]),
            FlowStep(id: 3, title: "Voice Note", prompt: "What's going on?", answers: [
                FlowAnswer(label: "Record", destination: .submit, recordVoiceNote: true)
            ])
        ],
        sourceUsername: nil,
        sourceFlowName: nil,
        visibility: "private",
        createdAt: nil
    )
}

#Preview {
    NavigationStack {
        WatchDynamicFlowView()
    }
}
