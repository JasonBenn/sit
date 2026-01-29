import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let notificationIdentifierPrefix = "sit.prompt."

    private init() {}

    // MARK: - Permission Management

    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        return try await notificationCenter.requestAuthorization(options: options)
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Notification Scheduling

    func schedulePromptNotifications(settings: PromptSettings) async throws {
        // Cancel existing notifications
        await cancelAllPromptNotifications()

        let count = Int(settings.promptsPerDay)
        let startHour = Int(settings.wakingHourStart)
        let endHour = Int(settings.wakingHourEnd)

        print("📅 Scheduling \(count) notifications between \(startHour):00 and \(endHour):00")

        // Generate random times for today and tomorrow
        let times = generateRandomTimes(
            count: count,
            startHour: startHour,
            endHour: endHour,
            daysAhead: 2 // Schedule for today and tomorrow
        )

        // Schedule each notification
        for (index, date) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Meditation Check-in"
            content.body = "In the View?"
            content.sound = .default
            content.categoryIdentifier = "PROMPT_CATEGORY"

            // Use calendar trigger for specific date/time
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "\(notificationIdentifierPrefix)\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            try await notificationCenter.add(request)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            print("  ✅ Scheduled notification \(index + 1) at \(formatter.string(from: date))")
        }

        print("📱 Total notifications scheduled: \(times.count)")
    }

    func cancelAllPromptNotifications() async {
        // Get all pending notifications
        let pendingRequests = await notificationCenter.pendingNotificationRequests()

        // Filter for prompt notifications
        let promptIdentifiers = pendingRequests
            .filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }
            .map { $0.identifier }

        // Cancel them
        notificationCenter.removePendingNotificationRequests(withIdentifiers: promptIdentifiers)

        print("🗑️ Cancelled \(promptIdentifiers.count) pending notifications")
    }

    func listPendingNotifications() async -> [UNNotificationRequest] {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }
    }

    // MARK: - Private Helpers

    private func generateRandomTimes(
        count: Int,
        startHour: Int,
        endHour: Int,
        daysAhead: Int
    ) -> [Date] {
        var times: [Date] = []
        let calendar = Calendar.current

        for dayOffset in 0..<daysAhead {
            // Get the target day
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else {
                continue
            }

            // Create start and end times for this day
            var startComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
            startComponents.hour = startHour
            startComponents.minute = 0

            var endComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
            endComponents.hour = endHour
            endComponents.minute = 0

            guard let startTime = calendar.date(from: startComponents),
                  let endTime = calendar.date(from: endComponents) else {
                continue
            }

            // Skip if the time window has already passed for today
            if dayOffset == 0 && Date() > endTime {
                print("⚠️ Skipping today - waking hours already passed")
                continue
            }

            // Calculate time window in seconds
            let windowStart = dayOffset == 0 ? max(Date().timeIntervalSince1970, startTime.timeIntervalSince1970) : startTime.timeIntervalSince1970
            let windowEnd = endTime.timeIntervalSince1970
            let windowDuration = windowEnd - windowStart

            guard windowDuration > 0 else {
                print("⚠️ No valid time window for day offset \(dayOffset)")
                continue
            }

            // Divide window into equal segments for even distribution
            let segmentDuration = windowDuration / Double(count)

            // Generate one random time in each segment
            for i in 0..<count {
                let segmentStart = windowStart + (segmentDuration * Double(i))
                let segmentEnd = segmentStart + segmentDuration

                // Add some randomness within each segment (±30% of segment duration)
                let randomOffset = Double.random(in: 0...(segmentDuration * 0.6)) - (segmentDuration * 0.3)
                let randomTime = segmentStart + (segmentDuration / 2) + randomOffset

                // Clamp to valid window
                let clampedTime = min(max(randomTime, windowStart), windowEnd)
                let date = Date(timeIntervalSince1970: clampedTime)

                times.append(date)
            }
        }

        // Sort chronologically
        return times.sorted()
    }
}
