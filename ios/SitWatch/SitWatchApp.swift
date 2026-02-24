import SwiftUI
import WidgetKit

@main
struct SitWatchApp: App {
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
