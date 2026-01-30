import Foundation
import Combine

@MainActor
class SyncViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let watchConnectivity = WatchConnectivityService.shared
    private let notificationService = NotificationService.shared

    init() {
        setupWatchMessageHandler()

        // Schedule initial notifications (3 per day, 8am-10pm)
        Task {
            await scheduleNotifications()
        }
    }

    // MARK: - Prompt Response Handling

    func logPromptResponse(
        initialAnswer: String,
        gateExerciseResult: String?,
        finalState: String,
        voiceNoteDuration: Double?
    ) async {
        let now = Date().timeIntervalSince1970 * 1000 // milliseconds

        do {
            let response = try await apiService.logPromptResponse(
                respondedAt: now,
                initialAnswer: initialAnswer,
                gateExerciseResult: gateExerciseResult,
                finalState: finalState,
                voiceNoteDuration: voiceNoteDuration
            )
            print("✅ Logged prompt response: \(response.id ?? "unknown")")
        } catch {
            errorMessage = "Failed to log response: \(error.localizedDescription)"
            print("❌ Response logging error: \(error)")
        }
    }

    // MARK: - Meditation Session Handling

    func logMeditationSession(
        durationMinutes: Int,
        startedAt: Double,
        completedAt: Double,
        hasInnerTimers: Bool
    ) async {
        do {
            let session = try await apiService.logMeditationSession(
                durationMinutes: durationMinutes,
                startedAt: startedAt,
                completedAt: completedAt,
                hasInnerTimers: hasInnerTimers
            )
            print("✅ Logged meditation session: \(session.id ?? "unknown")")
        } catch {
            errorMessage = "Failed to log session: \(error.localizedDescription)"
            print("❌ Session logging error: \(error)")
        }
    }

    // MARK: - Private Methods

    private func setupWatchMessageHandler() {
        watchConnectivity.onMessageReceived = { [weak self] messageType, data in
            guard let self = self else { return }

            Task { @MainActor in
                if messageType == "promptResponseV2" {
                    let initialAnswer = data["initialAnswer"] as? String ?? "in_view"
                    let gateExerciseResult = data["gateExerciseResult"] as? String
                    let finalState = data["finalState"] as? String ?? "reflection_complete"
                    let voiceNoteDuration = data["voiceNoteDuration"] as? Double

                    await self.logPromptResponse(
                        initialAnswer: initialAnswer,
                        gateExerciseResult: gateExerciseResult,
                        finalState: finalState,
                        voiceNoteDuration: voiceNoteDuration
                    )
                } else if messageType == "meditationSession" {
                    let durationMinutes = data["durationMinutes"] as? Int ?? 0
                    let startedAt = data["startedAt"] as? Double ?? 0
                    let completedAt = data["completedAt"] as? Double ?? 0
                    let hasInnerTimers = data["hasInnerTimers"] as? Bool ?? false

                    await self.logMeditationSession(
                        durationMinutes: durationMinutes,
                        startedAt: startedAt,
                        completedAt: completedAt,
                        hasInnerTimers: hasInnerTimers
                    )
                }
            }
        }
    }

    private func scheduleNotifications() async {
        do {
            let status = await notificationService.checkAuthorizationStatus()
            guard status == .authorized else {
                print("⚠️ Notifications not authorized")
                return
            }

            // Schedule 3 prompts per day between 8am and 10pm
            try await notificationService.schedulePromptNotifications(
                count: 3,
                startHour: 8,
                endHour: 22
            )
        } catch {
            print("❌ Failed to schedule notifications: \(error)")
        }
    }
}
