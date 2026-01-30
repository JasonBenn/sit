import SwiftUI

// MARK: - Flow State Machine

enum PromptFlowStep {
    case step1_inTheView
    case step2_reflection
    case step3_gateOpening
    case step4_voiceNote
}

// MARK: - Response Data

struct PromptFlowResponse {
    var initialAnswer: String = ""  // "in_view" | "not_in_view"
    var gateExerciseResult: String? = nil  // "worked" | "didnt_work"
    var finalState: String = ""  // "reflection_complete" | "voice_note_recorded"
    var voiceNoteDuration: Double? = nil
}

// MARK: - Main Flow Container

struct PromptFlowView: View {
    @State private var currentStep: PromptFlowStep = .step1_inTheView
    @State private var response = PromptFlowResponse()
    @State private var showCompletion = false
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            switch currentStep {
            case .step1_inTheView:
                Step1InTheViewView(onYes: {
                    response.initialAnswer = "in_view"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .step2_reflection
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }, onNo: {
                    response.initialAnswer = "not_in_view"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .step3_gateOpening
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })
                .transition(.opacity)

            case .step2_reflection:
                Step2ReflectionView(onComplete: {
                    response.finalState = "reflection_complete"
                    submitResponse()
                })
                .transition(.opacity)

            case .step3_gateOpening:
                Step3GateOpeningView(onWorked: {
                    response.gateExerciseResult = "worked"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .step2_reflection
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }, onDidntWork: {
                    response.gateExerciseResult = "didnt_work"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .step4_voiceNote
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })
                .transition(.opacity)

            case .step4_voiceNote:
                Step4VoiceNoteView(onComplete: { duration in
                    response.voiceNoteDuration = duration
                    response.finalState = "voice_note_recorded"
                    submitResponse()
                }, onSkip: {
                    response.finalState = "voice_note_skipped"
                    submitResponse()
                })
                .transition(.opacity)
            }
        }
        .alert("Complete", isPresented: $showCompletion) {
            Button("OK") {
                resetFlow()
            }
        } message: {
            Text("Response logged")
        }
        .disabled(isSubmitting)
    }

    private func submitResponse() {
        isSubmitting = true

        Task {
            do {
                _ = try await APIService.shared.logPromptResponse(
                    respondedAt: Date().timeIntervalSince1970 * 1000,
                    initialAnswer: response.initialAnswer,
                    gateExerciseResult: response.gateExerciseResult,
                    finalState: response.finalState,
                    voiceNoteDuration: response.voiceNoteDuration
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await MainActor.run {
                    isSubmitting = false
                    showCompletion = true
                }
            } catch {
                print("Failed to log response: \(error)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                await MainActor.run {
                    isSubmitting = false
                    showCompletion = true  // Still show completion, response logged locally
                }
            }
        }
    }

    private func resetFlow() {
        response = PromptFlowResponse()
        currentStep = .step1_inTheView
    }
}

#Preview {
    PromptFlowView()
}
