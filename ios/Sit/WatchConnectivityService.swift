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

            // Handle prompt response V2 from Watch
            if let responseData = message["promptResponseV2"] as? [String: Any] {
                onMessageReceived?("promptResponseV2", responseData)
            }
        }
    }
}
