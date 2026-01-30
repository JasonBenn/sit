import SwiftUI
import Sentry

@main
struct SitApp: App {
    init() {
        // Initialize Sentry
        SentrySDK.start { options in
            options.dsn = "https://76e762c7ead81d94d112ae535a342aa3@o4505288318386176.ingest.us.sentry.io/4510796961021952"
            options.tracesSampleRate = 1.0
            options.profilesSampleRate = 1.0
        }

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
