import Combine
import Foundation

@MainActor
final class StudySettings: ObservableObject {
    static let shared = StudySettings()

    private static let examKey = "pettyoptician.selectedExam"
    private static let studyDaysKey = "pettyoptician.studyDays"
    private static let dailyCardLimitKey = "pettyoptician.dailyNewCards"
    private static let examDatesKey = "pettyoptician.examDates"
    private static let reminderKey = "pettyoptician.reminderEnabled"
    private static let reminderMinutesKey = "pettyoptician.reminderMinutes"

    @Published var exam: ExamID {
        didSet { UserDefaults.standard.set(exam.rawValue, forKey: Self.examKey) }
    }

    @Published var dailyNewCards: Int {
        didSet { UserDefaults.standard.set(dailyNewCards, forKey: Self.dailyCardLimitKey) }
    }

    @Published private var examDateStamps: [String: Double] {
        didSet { UserDefaults.standard.set(examDateStamps, forKey: Self.examDatesKey) }
    }

    @Published var reminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(reminderEnabled, forKey: Self.reminderKey)
            Task { await StudyReminder.sync(self) }
        }
    }

    /// Minutes after midnight for the daily reminder.
    @Published var reminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(reminderMinutes, forKey: Self.reminderMinutesKey)
            Task { await StudyReminder.sync(self) }
        }
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
        examDateStamps = defaults.dictionary(forKey: Self.examDatesKey) as? [String: Double] ?? [:]
        reminderEnabled = defaults.bool(forKey: Self.reminderKey)
        reminderMinutes = defaults.object(forKey: Self.reminderMinutesKey) as? Int ?? 19 * 60
    }

    func examDate(for exam: ExamID) -> Date? {
        examDateStamps[exam.rawValue].map(Date.init(timeIntervalSince1970:))
    }

    func setExamDate(_ date: Date?, for exam: ExamID) {
        examDateStamps[exam.rawValue] = date?.timeIntervalSince1970
    }

    func daysUntilExam(_ exam: ExamID, from now: Date = .now) -> Int? {
        examDate(for: exam).map {
            Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: Calendar.current.startOfDay(for: $0)).day ?? 0
        }
    }

    var reminderTime: Date {
        get { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderMinutes = (c.hour ?? 19) * 60 + (c.minute ?? 0)
        }
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
