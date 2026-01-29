import SwiftUI
import WatchKit

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
    @EnvironmentObject var viewModel: WatchViewModel
    @State private var currentStep: PromptFlowStep = .step1_inTheView
    @State private var response = PromptFlowResponse()
    @State private var showCompletion = false

    var body: some View {
        NavigationView {
            ZStack {
                switch currentStep {
                case .step1_inTheView:
                    Step1InTheViewView(onYes: {
                        response.initialAnswer = "in_view"
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .step2_reflection
                        }
                        WKInterfaceDevice.current().play(.click)
                    }, onNo: {
                        response.initialAnswer = "not_in_view"
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .step3_gateOpening
                        }
                        WKInterfaceDevice.current().play(.click)
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
                        WKInterfaceDevice.current().play(.click)
                    }, onDidntWork: {
                        response.gateExerciseResult = "didnt_work"
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .step4_voiceNote
                        }
                        WKInterfaceDevice.current().play(.click)
                    })
                    .transition(.opacity)

                case .step4_voiceNote:
                    Step4VoiceNoteView(onComplete: { duration in
                        response.voiceNoteDuration = duration
                        response.finalState = "voice_note_recorded"
                        submitResponse()
                    }, onSkip: {
                        response.finalState = "voice_note_recorded"
                        submitResponse()
                    })
                    .transition(.opacity)
                }
            }
            .navigationTitle("Prompt")
            .alert("Complete", isPresented: $showCompletion) {
                Button("OK") {
                    resetFlow()
                }
            } message: {
                Text("Response logged")
            }
        }
    }

    private func submitResponse() {
        viewModel.logPromptResponseV2(
            initialAnswer: response.initialAnswer,
            gateExerciseResult: response.gateExerciseResult,
            finalState: response.finalState,
            voiceNoteDuration: response.voiceNoteDuration
        )
        WKInterfaceDevice.current().play(.success)
        showCompletion = true
    }

    private func resetFlow() {
        response = PromptFlowResponse()
        currentStep = .step1_inTheView
    }
}

#Preview {
    PromptFlowView()
        .environmentObject(WatchViewModel())
}
