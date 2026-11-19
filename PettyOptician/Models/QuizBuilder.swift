import Foundation

struct QuizConfig: Hashable, Sendable {
    enum Source: String, CaseIterable, Identifiable, Sendable {
        case all, unseen, missed, unsure, flagged

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: "All"
            case .unseen: "Unseen"
            case .missed: "Missed"
            case .unsure: "Unsure"
            case .flagged: "Flagged"
            }
        }

        var caption: String {
            switch self {
            case .all: "Every question in the selected sections"
            case .unseen: "Questions you haven't answered yet"
            case .missed: "Wrong the last time you answered"
            case .unsure: "Right last time, but missed before"
            case .flagged: "Questions you flagged"
            }
        }
    }

    var exam: ExamID
    var title: String
    var domains: Set<String> = []
    var count: Int = 20
    var difficulties: Set<Int> = []
    var source: Source = .all
    var timeLimitSeconds: Int?
    var pretestIDs: Set<String> = []

    var isTimed: Bool { timeLimitSeconds != nil }
}

struct WeakSection: Sendable {
    let domain: ExamDomain
    let accuracy: Double?

    var subtitle: String {
        "\(domain.name) · " + (accuracy.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "not started")
    }
}

struct QuestionHistory: Sendable {
    let seen: Int
    let correct: Int
    let lastWasCorrect: Bool
    let flagged: Bool
    let lastAnswered: Date
    var reviewDue: Date? = nil
}

enum QuizBuilder {
    static func questions(
        for config: QuizConfig,
        library: ContentLibrary,
        history: [String: QuestionHistory]
    ) -> [Question] {
        Array(pool(for: config, library: library, history: history).shuffled().prefix(config.count))
    }

    static func pool(for config: QuizConfig, library: ContentLibrary, history: [String: QuestionHistory]) -> [Question] {
        library.questions(for: config.exam).filter { q in
            (config.domains.isEmpty || config.domains.contains(q.domain))
                && (config.difficulties.isEmpty || config.difficulties.contains(q.difficulty))
                && matches(config.source, history[q.id])
        }
    }

    /// Unseen first, then missed, then least recently answered.
    static func weakFirst(
        exam: ExamID,
        domain: String? = nil,
        count: Int,
        library: ContentLibrary,
        history: [String: QuestionHistory]
    ) -> [Question] {
        weakFirst(library.questions(for: exam, domain: domain), count: count, history: history)
    }

    static func weakFirst(_ pool: [Question], count: Int, history: [String: QuestionHistory]) -> [Question] {
        let ranked = pool.shuffled().sorted { a, b in
            rank(history[a.id]) < rank(history[b.id])
        }
        return Array(ranked.prefix(count)).shuffled()
    }

    static func mockExam(_ exam: Exam, library: ContentLibrary) -> (questions: [Question], pretestIDs: Set<String>) {
        let target = exam.scoredQuestions ?? 100
        let available = library.questions(for: exam.id)
        let byDomain = Dictionary(grouping: available, by: \.domain)
        var scored: [Question] = []
        for domain in exam.domains {
            let count = Int((Double(target) * domain.weight / 100).rounded())
            scored += (byDomain[domain.id] ?? []).shuffled().prefix(count)
        }
        let used = Set(scored.map(\.id))
        var remaining = available.filter { !used.contains($0.id) }.shuffled()
        let shortfall = max(0, target - scored.count)
        scored += remaining.prefix(shortfall)
        remaining = Array(remaining.dropFirst(shortfall))
        let pilots = remaining.prefix(max(0, (exam.totalQuestions ?? target) - target))
        return ((scored + pilots).shuffled(), Set(pilots.map(\.id)))
    }

    /// Prefers questions never answered, then missed ones; the day key keeps the pick stable and spreads picks across the pool.
    static func dailyQuestion(from questions: [Question], history: [String: QuestionHistory], day: String) -> Question? {
        let unseen = questions.filter { matches(.unseen, history[$0.id]) }
        let missed = questions.filter { matches(.missed, history[$0.id]) }
        let pool = (unseen.isEmpty ? (missed.isEmpty ? questions : missed) : unseen).sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }
        let seed = day.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1.value)) &* 1_099_511_628_211 }
        return pool[Int(seed % UInt64(pool.count))]
    }

    /// Missed questions whose spaced re-check has come up, earliest first.
    static func dueForReview(_ questions: [Question], history: [String: QuestionHistory], at date: Date = .now) -> [Question] {
        questions
            .compactMap { q in history[q.id]?.reviewDue.flatMap { $0 <= date ? (q, $0) : nil } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    static func nextReview(_ questions: [Question], history: [String: QuestionHistory], after date: Date = .now) -> Date? {
        questions.compactMap { history[$0.id]?.reviewDue }.filter { $0 > date }.min()
    }

    static let weakestSectionMinimum = 10

    /// The lowest-accuracy section once it's below 75% or every section has enough answers to judge;
    /// until then, the most heavily weighted section you haven't really started.
    static func weakestSection(_ exam: Exam, library: ContentLibrary, history: [String: QuestionHistory]) -> WeakSection? {
        var scored: [(domain: ExamDomain, accuracy: Double)] = []
        var unstarted: [ExamDomain] = []
        for domain in exam.domains {
            let answered = library.questions(for: exam.id, domain: domain.id).compactMap { history[$0.id] }.filter { $0.seen > 0 }
            if answered.count >= weakestSectionMinimum {
                scored.append((domain, Double(answered.filter(\.lastWasCorrect).count) / Double(answered.count)))
            } else {
                unstarted.append(domain)
            }
        }
        if let weakest = scored.min(by: { $0.accuracy < $1.accuracy }), weakest.accuracy < 0.75 || unstarted.isEmpty {
            return WeakSection(domain: weakest.domain, accuracy: weakest.accuracy)
        }
        return unstarted.max { $0.weight < $1.weight }.map { WeakSection(domain: $0, accuracy: nil) }
    }

    static func matches(_ source: QuizConfig.Source, _ h: QuestionHistory?) -> Bool {
        switch source {
        case .all: true
        case .unseen: (h?.seen ?? 0) == 0
        case .missed: h.map { $0.seen > 0 && !$0.lastWasCorrect } ?? false
        case .unsure: h.map { $0.lastWasCorrect && $0.seen > $0.correct } ?? false
        case .flagged: h?.flagged ?? false
        }
    }

    private static func rank(_ h: QuestionHistory?) -> Double {
        guard let h, h.seen > 0 else { return 0 }
        if !h.lastWasCorrect { return 1 }
        return 2 + h.lastAnswered.timeIntervalSince1970 / 1e10
    }
}
