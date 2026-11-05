import Combine
import Foundation

@MainActor
final class StudySettings: ObservableObject {
    static let shared = StudySettings()

    private static let examKey = "enveoptician.selectedExam"
    private static let studyDaysKey = "enveoptician.studyDays"
    private static let dailyCardLimitKey = "enveoptician.dailyNewCards"

    @Published var exam: ExamID {
        didSet { UserDefaults.standard.set(exam.rawValue, forKey: Self.examKey) }
    }

    @Published var dailyNewCards: Int {
        didSet { UserDefaults.standard.set(dailyNewCards, forKey: Self.dailyCardLimitKey) }
    }

    @Published private(set) var studyDays: Set<String> {
        didSet { UserDefaults.standard.set(Array(studyDays), forKey: Self.studyDaysKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        exam = defaults.string(forKey: Self.examKey).flatMap(ExamID.init(rawValue:)) ?? .abo
        studyDays = Set(defaults.stringArray(forKey: Self.studyDaysKey) ?? [])
        let limit = defaults.integer(forKey: Self.dailyCardLimitKey)
        dailyNewCards = limit == 0 ? 20 : limit
    }

    func recordStudy(on date: Date = .now) {
        studyDays.insert(Self.dayKey(date))
    }

    func resetStreak() { studyDays = [] }

    var streak: Int {
        var count = 0
        var day = Date.now
        if !studyDays.contains(Self.dayKey(day)) {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while studyDays.contains(Self.dayKey(day)) {
            count += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
