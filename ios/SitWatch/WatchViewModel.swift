import Foundation
import WatchConnectivity

@MainActor
class WatchViewModel: NSObject, ObservableObject {
    @Published var isConnectedToiPhone = false

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("⌚ WatchConnectivity: Watch session activated")
        }
    }

    // MARK: - Send Prompt Response to iOS

    func logPromptResponseV2(
        initialAnswer: String,
        gateExerciseResult: String?,
        finalState: String,
        voiceNoteDuration: Double?
    ) {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }

        var responseData: [String: Any] = [
            "initialAnswer": initialAnswer,
            "finalState": finalState
        ]

        if let gateResult = gateExerciseResult {
            responseData["gateExerciseResult"] = gateResult
        }

        if let duration = voiceNoteDuration {
            responseData["voiceNoteDuration"] = duration
        }

        let message: [String: Any] = [
            "promptResponseV2": responseData
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Error sending prompt response: \(error.localizedDescription)")
        }

        print("⌚ Sent prompt response V2 to iPhone: \(responseData)")
    }

    // MARK: - Send Meditation Session to iOS

    func logMeditationSession(
        durationMinutes: Int,
        startedAt: Double,
        completedAt: Double,
        hasInnerTimers: Bool
    ) {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }

        let sessionData: [String: Any] = [
            "durationMinutes": durationMinutes,
            "startedAt": startedAt,
            "completedAt": completedAt,
            "hasInnerTimers": hasInnerTimers
        ]

        let message: [String: Any] = [
            "meditationSession": sessionData
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Error sending meditation session: \(error.localizedDescription)")
        }

        print("⌚ Sent meditation session to iPhone: \(sessionData)")
    }
}

// MARK: - WCSessionDelegate

extension WatchViewModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ WatchConnectivity activation failed: \(error.localizedDescription)")
            } else {
                print("✅ WatchConnectivity activated with state: \(activationState.rawValue)")
                isConnectedToiPhone = session.isReachable
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isConnectedToiPhone = session.isReachable
            print("⌚ iPhone reachability changed: \(session.isReachable)")
        }
    }
}
