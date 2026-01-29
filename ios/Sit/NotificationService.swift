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

    func schedulePromptNotifications(count: Int, startHour: Int, endHour: Int) async throws {
        // Cancel existing notifications
        await cancelAllPromptNotifications()

        print("📅 Scheduling \(count) notifications between \(startHour):00 and \(endHour):00")

        // Generate random times for today and tomorrow
        let times = generateRandomTimes(
            count: count,
            startHour: startHour,
            endHour: endHour,
            daysAhead: 2
        )

        // Schedule each notification
        for (index, date) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Meditation Check-in"
            content.body = "In the View?"
            content.sound = .default
            content.categoryIdentifier = "PROMPT_CATEGORY"

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
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let promptIdentifiers = pendingRequests
            .filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: promptIdentifiers)
        print("🗑️ Cancelled \(promptIdentifiers.count) pending notifications")
    }

    // MARK: - Private Helpers

    private func generateRandomTimes(count: Int, startHour: Int, endHour: Int, daysAhead: Int) -> [Date] {
        var times: [Date] = []
        let calendar = Calendar.current

        for dayOffset in 0..<daysAhead {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else {
                continue
            }

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

            if dayOffset == 0 && Date() > endTime {
                continue
            }

            let windowStart = dayOffset == 0 ? max(Date().timeIntervalSince1970, startTime.timeIntervalSince1970) : startTime.timeIntervalSince1970
            let windowEnd = endTime.timeIntervalSince1970
            let windowDuration = windowEnd - windowStart

            guard windowDuration > 0 else { continue }

            let segmentDuration = windowDuration / Double(count)

            for i in 0..<count {
                let segmentStart = windowStart + (segmentDuration * Double(i))
                let randomOffset = Double.random(in: 0...(segmentDuration * 0.6)) - (segmentDuration * 0.3)
                let randomTime = segmentStart + (segmentDuration / 2) + randomOffset
                let clampedTime = min(max(randomTime, windowStart), windowEnd)
                let date = Date(timeIntervalSince1970: clampedTime)
                times.append(date)
            }
        }

        return times.sorted()
    }
}
