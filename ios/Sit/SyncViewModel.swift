import Foundation
import Combine

@MainActor
class SyncViewModel: ObservableObject {
    @Published var beliefs: [Belief] = []
    @Published var timerPresets: [TimerPreset] = []
    @Published var promptSettings: PromptSettings?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?

    private let convexService = ConvexService()
    private let watchConnectivity = WatchConnectivityService.shared
    private let notificationService = NotificationService.shared
    private var syncTimer: Timer?

    init() {
        // Set up Watch message handler
        setupWatchMessageHandler()

        // Start periodic sync every 30 seconds
        startPeriodicSync()
    }

    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - Sync Methods

    func syncAll() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch all data from Convex in parallel
            async let beliefsTask = convexService.listBeliefs()
            async let presetsTask = convexService.listTimerPresets()
            async let settingsTask = convexService.getPromptSettings()

            let (fetchedBeliefs, fetchedPresets, fetchedSettings) = try await (beliefsTask, presetsTask, settingsTask)

            beliefs = fetchedBeliefs
            timerPresets = fetchedPresets
            promptSettings = fetchedSettings
            lastSyncDate = Date()

            // Send data to Watch after successful sync
            watchConnectivity.sendBeliefs(beliefs)
            watchConnectivity.sendTimerPresets(timerPresets)
            if let settings = promptSettings {
                watchConnectivity.sendPromptSettings(settings)
            }

            // Schedule notifications based on updated settings
            if let settings = fetchedSettings {
                await scheduleNotifications(settings: settings)
            }

            print("✅ Sync complete: \(beliefs.count) beliefs, \(timerPresets.count) presets")
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
            print("❌ Sync error: \(error)")
        }

        isLoading = false
    }

    func logMeditationSession(durationMinutes: Double) async {
        let now = Date().timeIntervalSince1970 * 1000 // Convex uses milliseconds
        let startedAt = now - (durationMinutes * 60 * 1000)

        do {
            let sessionId = try await convexService.logMeditationSession(
                durationMinutes: durationMinutes,
                startedAt: startedAt,
                completedAt: now,
                hasInnerTimers: false
            )
            print("✅ Logged meditation session: \(sessionId)")
        } catch {
            errorMessage = "Failed to log session: \(error.localizedDescription)"
            print("❌ Session logging error: \(error)")
        }
    }

    func logPromptResponse(inTheView: Bool) async {
        let now = Date().timeIntervalSince1970 * 1000 // Convex uses milliseconds

        do {
            let responseId = try await convexService.logPromptResponse(
                inTheView: inTheView,
                respondedAt: now
            )
            print("✅ Logged prompt response: \(responseId)")
        } catch {
            errorMessage = "Failed to log response: \(error.localizedDescription)"
            print("❌ Response logging error: \(error)")
        }
    }

    func createBelief(text: String) async {
        do {
            let beliefId = try await convexService.createBelief(text: text)
            print("✅ Created belief: \(beliefId)")
            // Refresh beliefs after creating
            await syncAll()
        } catch {
            errorMessage = "Failed to create belief: \(error.localizedDescription)"
            print("❌ Belief creation error: \(error)")
        }
    }

    func createTimerPreset(durationMinutes: Double, label: String?) async {
        do {
            let presetId = try await convexService.createTimerPreset(durationMinutes: durationMinutes, label: label)
            print("✅ Created timer preset: \(presetId)")
            await syncAll()
        } catch {
            errorMessage = "Failed to create preset: \(error.localizedDescription)"
            print("❌ Preset creation error: \(error)")
        }
    }

    // MARK: - Private Methods

    private func setupWatchMessageHandler() {
        watchConnectivity.onMessageReceived = { [weak self] messageType, data in
            guard let self = self else { return }

            Task { @MainActor in
                switch messageType {
                case "meditationSession":
                    if let durationMinutes = data["durationMinutes"] as? Double {
                        await self.logMeditationSession(durationMinutes: durationMinutes)
                    }

                case "promptResponse":
                    if let inTheView = data["inTheView"] as? Bool {
                        await self.logPromptResponse(inTheView: inTheView)
                    }

                case "newBelief":
                    if let text = data["text"] as? String {
                        await self.createBelief(text: text)
                    }

                default:
                    print("⚠️ Unknown message type: \(messageType)")
                }
            }
        }
    }

    private func startPeriodicSync() {
        // Initial sync
        Task {
            await syncAll()
        }

        // Periodic sync every 30 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
            }
        }
    }

    private func scheduleNotifications(settings: PromptSettings) async {
        do {
            // Check if we have permission
            let status = await notificationService.checkAuthorizationStatus()
            guard status == .authorized else {
                print("⚠️ Notifications not authorized - skipping scheduling")
                return
            }

            // Schedule notifications
            try await notificationService.schedulePromptNotifications(settings: settings)
        } catch {
            print("❌ Failed to schedule notifications: \(error)")
        }
    }
}
