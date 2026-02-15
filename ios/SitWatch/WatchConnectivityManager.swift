import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var currentFlow: FlowDefinition?
    @Published var authToken: String?
    @Published var notificationSettings: (count: Int, startHour: Int, endHour: Int)?

    private let flowKey = "watch_current_flow"
    private let tokenKey = "watch_auth_token"
    private let notifCountKey = "watch_notif_count"
    private let notifStartKey = "watch_notif_start_hour"
    private let notifEndKey = "watch_notif_end_hour"

    override init() {
        super.init()
        loadFromDefaults()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: flowKey),
           let flow = try? JSONDecoder().decode(FlowDefinition.self, from: data) {
            currentFlow = flow
        }

        authToken = defaults.string(forKey: tokenKey)

        let count = defaults.integer(forKey: notifCountKey)
        if count > 0 {
            notificationSettings = (
                count: count,
                startHour: defaults.integer(forKey: notifStartKey),
                endHour: defaults.integer(forKey: notifEndKey)
            )
        }
    }

    private func saveFlow(_ flow: FlowDefinition) {
        if let data = try? JSONEncoder().encode(flow) {
            UserDefaults.standard.set(data, forKey: flowKey)
        }
        currentFlow = flow
    }

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        authToken = token
    }

    private func saveNotificationSettings(count: Int, startHour: Int, endHour: Int) {
        let defaults = UserDefaults.standard
        defaults.set(count, forKey: notifCountKey)
        defaults.set(startHour, forKey: notifStartKey)
        defaults.set(endHour, forKey: notifEndKey)
        notificationSettings = (count: count, startHour: startHour, endHour: endHour)
    }

    nonisolated private func handleMessage(_ message: [String: Any]) {
        Task { @MainActor in
            if let flowJSON = message["flow_json"] as? Data,
               let flow = try? JSONDecoder().decode(FlowDefinition.self, from: flowJSON) {
                saveFlow(flow)
            }

            if let token = message["auth_token"] as? String {
                saveToken(token)
            }

            if let count = message["notification_count"] as? Int,
               let startHour = message["notification_start_hour"] as? Int,
               let endHour = message["notification_end_hour"] as? Int {
                saveNotificationSettings(count: count, startHour: startHour, endHour: endHour)
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleMessage(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleMessage(userInfo)
    }
}
