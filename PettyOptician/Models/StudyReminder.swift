import Foundation
import UserNotifications

enum StudyReminder {
    private static let identifier = "pettyoptician.daily-study"

    @MainActor
    static func sync(_ settings: StudySettings) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard settings.reminderEnabled else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else {
            settings.reminderEnabled = false
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time for your next lesson"
        content.body = "Continue your textbook or review a missed question."
        content.sound = .default

        var components = DateComponents()
        components.hour = settings.reminderMinutes / 60
        components.minute = settings.reminderMinutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
