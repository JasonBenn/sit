import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false

    private var session: WCSession?

    // Callback for receiving messages from Watch
    var onMessageReceived: ((String, [String: Any]) -> Void)?

    override private init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("📱 WatchConnectivity: iOS session activated")
        }
    }

    // MARK: - Send Data to Watch

    func sendBeliefs(_ beliefs: [Belief]) {
        guard let session = session, session.isWatchAppInstalled else {
            print("⚠️ Watch app not installed, skipping beliefs sync")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(beliefs)
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            let message: [String: Any] = ["beliefs": json]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("❌ Error sending beliefs: \(error.localizedDescription)")
                }
                print("📱 Sent \(beliefs.count) beliefs to Watch")
            } else {
                try session.updateApplicationContext(message)
                print("📱 Updated context with \(beliefs.count) beliefs (Watch not reachable)")
            }
        } catch {
            print("❌ Error encoding beliefs: \(error.localizedDescription)")
        }
    }

    func sendTimerPresets(_ presets: [TimerPreset]) {
        guard let session = session, session.isWatchAppInstalled else {
            print("⚠️ Watch app not installed, skipping presets sync")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(presets)
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            let message: [String: Any] = ["timerPresets": json]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("❌ Error sending timer presets: \(error.localizedDescription)")
                }
                print("📱 Sent \(presets.count) timer presets to Watch")
            } else {
                try session.updateApplicationContext(message)
                print("📱 Updated context with \(presets.count) timer presets (Watch not reachable)")
            }
        } catch {
            print("❌ Error encoding timer presets: \(error.localizedDescription)")
        }
    }

    func sendPromptSettings(_ settings: PromptSettings) {
        guard let session = session, session.isWatchAppInstalled else {
            print("⚠️ Watch app not installed, skipping settings sync")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            let message: [String: Any] = ["promptSettings": json]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("❌ Error sending prompt settings: \(error.localizedDescription)")
                }
                print("📱 Sent prompt settings to Watch")
            } else {
                try session.updateApplicationContext(message)
                print("📱 Updated context with prompt settings (Watch not reachable)")
            }
        } catch {
            print("❌ Error encoding prompt settings: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ WatchConnectivity activation failed: \(error.localizedDescription)")
            } else {
                print("✅ WatchConnectivity activated with state: \(activationState.rawValue)")
                isWatchAppInstalled = session.isWatchAppInstalled
                isWatchReachable = session.isReachable
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WatchConnectivity session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WatchConnectivity session deactivated")
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            print("📱 Watch reachability changed: \(session.isReachable)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            print("📱 Received message from Watch: \(message.keys.joined(separator: ", "))")

            // Handle meditation session from Watch
            if let sessionData = message["meditationSession"] as? [String: Any] {
                onMessageReceived?("meditationSession", sessionData)
            }

            // Handle prompt response from Watch
            if let responseData = message["promptResponse"] as? [String: Any] {
                onMessageReceived?("promptResponse", responseData)
            }

            // Handle new belief from Watch
            if let beliefData = message["newBelief"] as? [String: Any] {
                onMessageReceived?("newBelief", beliefData)
            }
        }
    }
}
