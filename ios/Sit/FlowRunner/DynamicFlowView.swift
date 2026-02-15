import SwiftUI

struct DynamicFlowView: View {
    let flow: FlowDefinition
    var isPreview: Bool = false
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currentStepId: Int
    @State private var collectedSteps: [(stepId: Int, answerIdx: Int)] = []
    @State private var showConfirmation = false
    @State private var showVoiceRecorder = false
    @State private var pendingDestination: AnswerDestination?
    @State private var voiceRecorderPrompt = ""
    @State private var voiceNoteDuration: Double?
    @State private var voiceNoteData: Data?
    @State private var isSubmitting = false

    init(flow: FlowDefinition, isPreview: Bool = false, onComplete: (() -> Void)? = nil) {
        self.flow = flow
        self.isPreview = isPreview
        self.onComplete = onComplete
        self._currentStepId = State(initialValue: flow.stepsJson.first?.id ?? 0)
    }

    private var currentStep: FlowStep? {
        flow.stepsJson.first(where: { $0.id == currentStepId })
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if showConfirmation {
                confirmationOverlay
                    .transition(.opacity)
            } else if showVoiceRecorder {
                VoiceRecorderView(
                    prompt: voiceRecorderPrompt,
                    onSave: { duration, data in
                        voiceNoteDuration = duration
                        voiceNoteData = data
                        showVoiceRecorder = false
                        processPendingDestination()
                    },
                    onSkip: {
                        showVoiceRecorder = false
                        processPendingDestination()
                    }
                )
                .transition(.opacity)
            } else if let step = currentStep {
                DynamicStepView(
                    step: step,
                    stepNumber: collectedSteps.count + 1,
                    totalSteps: flow.stepsJson.count,
                    onAnswer: { answerIdx in
                        handleAnswer(step: step, answerIdx: answerIdx)
                    }
                )
                .id(currentStepId)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStepId)
        .animation(.easeInOut(duration: 0.3), value: showConfirmation)
        .animation(.easeInOut(duration: 0.3), value: showVoiceRecorder)
        .disabled(isSubmitting)
        .navigationBarBackButtonHidden(showConfirmation)
    }

    private func handleAnswer(step: FlowStep, answerIdx: Int) {
        collectedSteps.append((stepId: step.id, answerIdx: answerIdx))

        let answer = step.answers[answerIdx]

        if answer.recordVoiceNote {
            voiceRecorderPrompt = step.prompt
            pendingDestination = answer.destination
            withAnimation {
                showVoiceRecorder = true
            }
        } else {
            processDestination(answer.destination)
        }
    }

    private func processPendingDestination() {
        guard let destination = pendingDestination else { return }
        pendingDestination = nil
        processDestination(destination)
    }

    private func processDestination(_ destination: AnswerDestination) {
        switch destination {
        case .step(let nextId):
            withAnimation {
                currentStepId = nextId
            }
        case .submit:
            submitResponse()
        }
    }

    private func submitResponse() {
        isSubmitting = true

        if isPreview {
            withAnimation {
                showConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onComplete?() ?? dismiss()
            }
            return
        }

        let steps = collectedSteps.map { [$0.stepId, $0.answerIdx] }

        Task {
            _ = try await APIService.shared.logPromptResponse(
                respondedAt: Date().timeIntervalSince1970 * 1000,
                flowId: flow.id,
                steps: steps,
                voiceNoteDuration: voiceNoteDuration,
                voiceNoteData: voiceNoteData,
                voiceNoteFilename: voiceNoteData != nil ? "voice_note.m4a" : nil
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await MainActor.run {
                withAnimation {
                    showConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onComplete?() ?? dismiss()
                }
            }
        }
    }

    private var confirmationOverlay: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Theme.sage.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(Theme.sageText)
            }

            Text(isPreview ? "Preview complete" : "Check-in saved")
                .font(Theme.display(24))
                .foregroundColor(Theme.text)
        }
    }
}
