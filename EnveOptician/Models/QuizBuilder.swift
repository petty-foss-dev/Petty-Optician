import Foundation

struct QuizConfig: Hashable, Sendable {
    enum Source: String, CaseIterable, Identifiable, Sendable {
        case all, unseen, missed, flagged

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: "All"
            case .unseen: "Unseen"
            case .missed: "Missed"
            case .flagged: "Flagged"
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

    var isTimed: Bool { timeLimitSeconds != nil }
}

struct QuestionHistory: Sendable {
    let seen: Int
    let lastWasCorrect: Bool
    let flagged: Bool
    let lastAnswered: Date
}

enum QuizBuilder {
    static func questions(
        for config: QuizConfig,
        library: ContentLibrary,
        history: [String: QuestionHistory]
    ) -> [Question] {
        let pool = library.questions(for: config.exam).filter { q in
            (config.domains.isEmpty || config.domains.contains(q.domain))
                && (config.difficulties.isEmpty || config.difficulties.contains(q.difficulty))
                && matches(config.source, history[q.id])
        }
        return Array(pool.shuffled().prefix(config.count))
    }

    /// Unseen first, then missed, then least recently answered.
    static func weakFirst(
        exam: ExamID,
        domain: String? = nil,
        count: Int,
        library: ContentLibrary,
        history: [String: QuestionHistory]
    ) -> [Question] {
        let ranked = library.questions(for: exam, domain: domain).shuffled().sorted { a, b in
            rank(history[a.id]) < rank(history[b.id])
        }
        return Array(ranked.prefix(count)).shuffled()
    }

    /// Allocates questions to domains in proportion to the published outline weights.
    static func mockExam(_ exam: Exam, library: ContentLibrary) -> [Question] {
        let target = exam.totalQuestions ?? exam.scoredQuestions ?? 100
        let pools = exam.domains.map { library.questions(for: exam.id, domain: $0.id).shuffled() }
        let totalWeight = exam.domains.map(\.weight).reduce(0, +)
        var picked: [Question] = []
        for (domain, pool) in zip(exam.domains, pools) {
            let share = totalWeight > 0
                ? Int((Double(target) * domain.weight / totalWeight).rounded())
                : target / max(1, exam.domains.count)
            picked += pool.prefix(share)
        }
        if picked.count < target {
            let used = Set(picked.map(\.id))
            let leftovers = pools.joined().filter { !used.contains($0.id) }.shuffled()
            picked += leftovers.prefix(target - picked.count)
        }
        return Array(picked.prefix(target)).shuffled()
    }

    private static func matches(_ source: QuizConfig.Source, _ h: QuestionHistory?) -> Bool {
        switch source {
        case .all: true
        case .unseen: (h?.seen ?? 0) == 0
        case .missed: h.map { $0.seen > 0 && !$0.lastWasCorrect } ?? false
        case .flagged: h?.flagged ?? false
        }
    }

    private static func rank(_ h: QuestionHistory?) -> Double {
        guard let h, h.seen > 0 else { return 0 }
        if !h.lastWasCorrect { return 1 }
        return 2 + h.lastAnswered.timeIntervalSince1970 / 1e10
    }
}
