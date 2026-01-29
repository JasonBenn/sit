import SwiftUI

@main
struct SitApp: App {
    init() {
        // Request notification permissions on app launch
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("⚠️ Notification permission denied")
                }
            } catch {
                print("❌ Failed to request notification permission: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
