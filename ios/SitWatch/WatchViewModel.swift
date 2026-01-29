import Foundation
import WatchConnectivity
import WidgetKit

// MARK: - Shared Storage for Complication

enum MeditationStorage {
    static let lastMeditationDateKey = "lastMeditationDate"

    static func didMeditateToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastMeditationDateKey) as? Date else {
            return false
        }

        return Calendar.current.isDateInToday(lastDate)
    }

    static func recordMeditation() {
        UserDefaults.standard.set(Date(), forKey: lastMeditationDateKey)
    }
}

// MARK: - View Model

@MainActor
class WatchViewModel: NSObject, ObservableObject {
    @Published var beliefs: [Belief] = []
    @Published var timerPresets: [TimerPreset] = []
    @Published var promptSettings: PromptSettings?
    @Published var isConnectedToiPhone = false

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("⌚ WatchConnectivity: Watch session activated")
        }

        // Add test data for development
        addTestPresets()
        addTestBeliefs()
    }

    private func addTestPresets() {
        // Only add test presets if none exist
        // Match Convex presets for f12 verification: 7 min "Short session", 20 min "Medium session", 45 min
        if timerPresets.isEmpty {
            timerPresets = [
                TimerPreset(
                    id: "test1",
                    durationMinutes: 7.0,
                    label: "Short session",
                    order: 0,
                    createdAt: Date().timeIntervalSince1970 * 1000
                ),
                TimerPreset(
                    id: "test2",
                    durationMinutes: 20.0,
                    label: "Medium session",
                    order: 1,
                    createdAt: Date().timeIntervalSince1970 * 1000
                ),
                TimerPreset(
                    id: "test3",
                    durationMinutes: 45.0,
                    label: nil,
                    order: 2,
                    createdAt: Date().timeIntervalSince1970 * 1000
                )
            ]
            print("⌚ Added test timer presets matching Convex data")
        }
    }

    private func addTestBeliefs() {
        // Add test beliefs for f13 verification
        if beliefs.isEmpty {
            let now = Date().timeIntervalSince1970 * 1000
            beliefs = [
                Belief(
                    id: "belief1",
                    text: "I need to be productive all the time",
                    createdAt: now - 86400000 * 7, // 7 days ago
                    updatedAt: now - 86400000 * 7
                ),
                Belief(
                    id: "belief2",
                    text: "My worth is determined by my accomplishments",
                    createdAt: now - 86400000 * 5, // 5 days ago
                    updatedAt: now - 86400000 * 5
                ),
                Belief(
                    id: "belief3",
                    text: "People will judge me if I make mistakes",
                    createdAt: now - 86400000 * 3, // 3 days ago
                    updatedAt: now - 86400000 * 3
                ),
                Belief(
                    id: "belief4",
                    text: "I must always be strong and never show weakness. Showing vulnerability means I'm failing at life and people will lose respect for me.",
                    createdAt: now - 86400000, // 1 day ago
                    updatedAt: now - 86400000
                ),
                Belief(
                    id: "belief5",
                    text: "Rest is laziness",
                    createdAt: now - 3600000, // 1 hour ago
                    updatedAt: now - 3600000
                )
            ]
            print("⌚ Added test beliefs for f13 verification")
        }
    }

    // MARK: - Send Events to iOS

    func logMeditationSession(durationMinutes: Double) {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }

        let message: [String: Any] = [
            "meditationSession": [
                "durationMinutes": durationMinutes
            ]
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Error sending meditation session: \(error.localizedDescription)")
        }

        // Record meditation date for complication
        MeditationStorage.recordMeditation()

        // Reload widget timelines to update complication
        WidgetCenter.shared.reloadAllTimelines()

        print("⌚ Sent meditation session to iPhone: \(durationMinutes) min")
        print("✅ Recorded meditation date and updated complication")
    }

    func logPromptResponse(inTheView: Bool) {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }

        let message: [String: Any] = [
            "promptResponse": [
                "inTheView": inTheView
            ]
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Error sending prompt response: \(error.localizedDescription)")
        }

        print("⌚ Sent prompt response to iPhone: \(inTheView)")
    }

    func createBelief(text: String) {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable")
            return
        }

        let message: [String: Any] = [
            "newBelief": [
                "text": text
            ]
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Error sending new belief: \(error.localizedDescription)")
        }

        print("⌚ Sent new belief to iPhone: \(text)")
    }
}

// MARK: - WCSessionDelegate

extension WatchViewModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ WatchConnectivity activation failed: \(error.localizedDescription)")
            } else {
                print("✅ WatchConnectivity activated with state: \(activationState.rawValue)")
                isConnectedToiPhone = session.isReachable
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isConnectedToiPhone = session.isReachable
            print("⌚ iPhone reachability changed: \(session.isReachable)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            print("⌚ Received message from iPhone: \(message.keys.joined(separator: ", "))")

            // Handle beliefs from iPhone
            if let beliefsData = message["beliefs"] as? [[String: Any]] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: beliefsData)
                    let decoder = JSONDecoder()
                    beliefs = try decoder.decode([Belief].self, from: jsonData)
                    print("⌚ Updated beliefs: \(beliefs.count) items")
                } catch {
                    print("❌ Error decoding beliefs: \(error)")
                }
            }

            // Handle timer presets from iPhone
            if let presetsData = message["timerPresets"] as? [[String: Any]] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: presetsData)
                    let decoder = JSONDecoder()
                    timerPresets = try decoder.decode([TimerPreset].self, from: jsonData)
                    print("⌚ Updated timer presets: \(timerPresets.count) items")
                } catch {
                    print("❌ Error decoding timer presets: \(error)")
                }
            }

            // Handle prompt settings from iPhone
            if let settingsData = message["promptSettings"] as? [String: Any] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: settingsData)
                    let decoder = JSONDecoder()
                    promptSettings = try decoder.decode(PromptSettings.self, from: jsonData)
                    print("⌚ Updated prompt settings")
                } catch {
                    print("❌ Error decoding prompt settings: \(error)")
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Handle application context updates (same as messages but for background updates)
        self.session(session, didReceiveMessage: applicationContext)
    }
}
