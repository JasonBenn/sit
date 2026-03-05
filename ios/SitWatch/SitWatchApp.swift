import SwiftUI
import WidgetKit
import WatchKit
import UserNotifications

extension Notification.Name {
    static let startCheckIn = Notification.Name("startCheckIn")
}

class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Notification tap from a local or remote notification — may carry an override flow.
    static var pendingCheckIn = false
    static var pendingFlow: FlowDefinition? = nil
    static var pendingScheduleType: String? = nil

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // Try to decode a flow embedded in the APNs payload
        if let stepsJsonString = userInfo["steps_json"] as? String,
           let stepsJsonData = stepsJsonString.data(using: .utf8),
           let flowId = userInfo["flow_id"] as? String,
           let flowName = userInfo["flow_name"] as? String {
            let decoder = JSONDecoder()
            if let steps = try? decoder.decode([FlowStep].self, from: stepsJsonData) {
                AppDelegate.pendingFlow = FlowDefinition(
                    id: flowId,
                    userId: nil,
                    name: flowName,
                    description: "",
                    stepsJson: steps,
                    sourceUsername: nil,
                    sourceFlowName: nil,
                    visibility: "private",
                    createdAt: nil
                )
            }
        }

        AppDelegate.pendingScheduleType = userInfo["schedule_type"] as? String
        AppDelegate.pendingCheckIn = true

        await MainActor.run {
            NotificationCenter.default.post(name: .startCheckIn, object: AppDelegate.pendingFlow)
        }
    }

    // MARK: - Remote notifications (APNs)

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📲 APNs device token: \(token)")
        Task {
            try? await APIService.shared.registerDeviceToken(token, platform: "watchos")
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("❌ APNs registration failed: \(error)")
    }
}

@main
struct SitWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = WatchAuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .task {
                    WidgetCenter.shared.reloadAllTimelines()
                    await ResponseQueue.shared.syncPending()
                    await setupNotifications()
                }
        }
    }

    private func setupNotifications() async {
        let service = NotificationService.shared
        do {
            let granted = try await service.requestAuthorization()
            guard granted else {
                print("⚠️ Notification permission denied")
                return
            }
            // Register for remote (APNs) push notifications
            WKApplication.shared().registerForRemoteNotifications()

            let settings = authManager.notificationSettings
            let perDay = settings?.count ?? 3
            let startHour = settings?.startHour ?? 9
            let endHour = settings?.endHour ?? 22
            try await service.schedulePromptNotifications(perDay: perDay, startHour: startHour, endHour: endHour)
            print("✅ Notifications scheduled")
        } catch {
            print("❌ Notification setup failed: \(error)")
        }
    }
}
