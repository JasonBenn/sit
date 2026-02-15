import SwiftUI
import WidgetKit

@main
struct SitWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    WatchConnectivityManager.shared.activate()
                    WidgetCenter.shared.reloadAllTimelines()
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
            try await service.schedulePromptNotifications()
            print("✅ Notifications scheduled")
        } catch {
            print("❌ Notification setup failed: \(error)")
        }
    }
}
