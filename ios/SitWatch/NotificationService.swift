import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let notificationIdentifierPrefix = "sit.prompt."

    private init() {}

    func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedulePromptNotifications(perDay: Int, startHour: Int, endHour: Int) async throws {
        await cancelAllPromptNotifications()

        // Apple caps local notifications at 64 per app. Fill them all.
        let daysAhead = 64 / perDay  // 21 days at 3/day
        let times = generateRandomTimes(count: perDay, startHour: startHour, endHour: endHour, daysAhead: daysAhead)

        for (index, date) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Meditation Check-in"
            content.body = "In the View?"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(notificationIdentifierPrefix)\(index)",
                content: content,
                trigger: trigger
            )

            try await notificationCenter.add(request)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            print("  ✅ Scheduled notification \(index + 1) at \(formatter.string(from: date))")
        }

        print("📱 Total notifications scheduled: \(times.count)")
    }

    private func cancelAllPromptNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let promptIdentifiers = pendingRequests
            .filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: promptIdentifiers)
    }

    private func generateRandomTimes(count: Int, startHour: Int, endHour: Int, daysAhead: Int) -> [Date] {
        var times: [Date] = []
        let calendar = Calendar.current

        for dayOffset in 0..<daysAhead {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            var startComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
            startComponents.hour = startHour
            startComponents.minute = 0

            var endComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
            endComponents.hour = endHour
            endComponents.minute = 0

            guard let startTime = calendar.date(from: startComponents),
                  let endTime = calendar.date(from: endComponents) else { continue }

            if dayOffset == 0 && Date() > endTime { continue }

            let windowStart = dayOffset == 0
                ? max(Date().timeIntervalSince1970, startTime.timeIntervalSince1970)
                : startTime.timeIntervalSince1970
            let windowEnd = endTime.timeIntervalSince1970
            let windowDuration = windowEnd - windowStart

            guard windowDuration > 0 else { continue }

            let segmentDuration = windowDuration / Double(count)

            for i in 0..<count {
                let segmentStart = windowStart + (segmentDuration * Double(i))
                let randomOffset = Double.random(in: 0...(segmentDuration * 0.6)) - (segmentDuration * 0.3)
                let randomTime = segmentStart + (segmentDuration / 2) + randomOffset
                let clampedTime = min(max(randomTime, windowStart), windowEnd)
                times.append(Date(timeIntervalSince1970: clampedTime))
            }
        }

        return times.sorted()
    }
}
