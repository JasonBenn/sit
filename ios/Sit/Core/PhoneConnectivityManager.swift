import WatchConnectivity
import Foundation

class PhoneConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendFlowToWatch(_ flow: FlowDefinition) {
        guard WCSession.default.isReachable else { return }
        guard let data = try? JSONEncoder().encode(flow),
              let json = String(data: data, encoding: .utf8) else { return }
        WCSession.default.transferUserInfo(["flow_json": json])
    }

    func sendNotificationSettingsToWatch(count: Int, startHour: Int, endHour: Int) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo([
            "notification_count": count,
            "notification_start_hour": startHour,
            "notification_end_hour": endHour,
        ])
    }

    func sendAuthTokenToWatch(_ token: String) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(["auth_token": token])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
