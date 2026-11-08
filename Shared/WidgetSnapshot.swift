import Foundation

/// What the app hands the widgets through the shared App Group; widgets never open the progress store.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct DailyQuestion: Codable, Equatable, Sendable {
        let id: String
        let stem: String
        let choices: [String]
        let answer: Int
        let section: String
        /// The day it belongs to, so an old question isn't shown after midnight.
        let day: String
    }

    var exam: String
    var daysUntilExam: Int?
    var cardsDue: Int
    var recheckDue: Int
    var streak: Int
    var readiness: Double
    var daily: DailyQuestion?

    static let appGroup = "group.com.isaaclamb.PettyOptician"
    private static let key = "widgetSnapshot"

    static let placeholder = WidgetSnapshot(
        exam: "ABO", daysUntilExam: 21, cardsDue: 12, recheckDue: 4, streak: 5, readiness: 0.62,
        daily: DailyQuestion(id: "", stem: "Which lens material has the highest Abbe value?", choices: ["Polycarbonate", "CR-39", "1.67 high-index", "Trivex"], answer: 1, section: "Ophthalmic Products", day: "")
    )

    static func load() -> WidgetSnapshot? {
        UserDefaults(suiteName: appGroup)?.data(forKey: key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }

    func save() {
        UserDefaults(suiteName: Self.appGroup)?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
