import Foundation

struct LessonRef: Hashable, Sendable {
    let domain: String
    let index: Int
}

// Authored checkpoints take precedence over text-overlap matches.
struct LessonLinks: Sendable {
    static let shared = LessonLinks(library: .shared)

    private let lessonByQuestion: [String: LessonRef]
    private let questionsByLesson: [LessonRef: [Question]]

    init(library: ContentLibrary) {
        var lessonByQuestion: [String: LessonRef] = [:]
        for guide in library.guides {
            for (index, section) in guide.sections.enumerated() {
                for id in section.checkpointIDs ?? [] {
                    lessonByQuestion[id] = LessonRef(domain: guide.domain, index: index)
                }
            }
        }
        for exam in ExamID.allCases {
            let lessons = library.domains(for: exam).flatMap { domain in
                (library.guide(for: domain.id)?.sections ?? []).enumerated().map { index, section in
                    (ref: LessonRef(domain: domain.id, index: index), terms: Self.counts(Self.tokens(section.heading), weight: 3, plus: Self.tokens(section.body)))
                }
            }
            guard lessons.count > 1 else { continue }
            var documentFrequency: [String: Int] = [:]
            for lesson in lessons { for term in lesson.terms.keys { documentFrequency[term, default: 0] += 1 } }
            let n = Double(lessons.count)
            let idf = documentFrequency.mapValues { log((n + 1) / (Double($0) + 0.5)) }

            for question in library.questions(for: exam) where lessonByQuestion[question.id] == nil {
                let query = Self.counts(
                    Self.tokens(question.topic),
                    weight: 3,
                    plus: Self.tokens([question.stem, question.choices[question.answer], question.explanation].joined(separator: " "))
                )
                let scores = lessons.map { lesson in
                    let overlap = query.reduce(0.0) { sum, entry in
                        guard let inLesson = lesson.terms[entry.key] else { return sum }
                        return sum + Double(min(entry.value, 3)) * (idf[entry.key] ?? 0) * log1p(Double(inLesson))
                    }
                    return overlap * (lesson.ref.domain == question.domain ? 1.25 : 1)
                }
                let ranked = scores.indices.sorted { scores[$0] > scores[$1] }
                let best = scores[ranked[0]], runnerUp = scores[ranked[1]]
                if best >= 12, best >= 1.25 * runnerUp || best >= 40 {
                    lessonByQuestion[question.id] = lessons[ranked[0]].ref
                }
            }
        }
        self.lessonByQuestion = lessonByQuestion
        let byID = Dictionary(library.questions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        questionsByLesson = Dictionary(grouping: lessonByQuestion.keys.sorted().compactMap { byID[$0] }) { lessonByQuestion[$0.id]! }
    }

    func lesson(for question: Question) -> LessonRef? { lessonByQuestion[question.id] }

    func questions(for lesson: LessonRef) -> [Question] { questionsByLesson[lesson] ?? [] }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "are", "with", "from", "that", "this", "which", "what", "when", "its", "into", "than",
        "then", "most", "best", "each", "per", "not", "can", "will", "should", "would", "used", "use", "using",
        "patient", "lens", "lenses"
    ]

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
            .map(stem)
    }

    private static func stem(_ word: String) -> String {
        for suffix in ["ing", "es", "s"] where word.hasSuffix(suffix) && word.count - suffix.count >= 4 {
            return String(word.dropLast(suffix.count))
        }
        return word
    }

    private static func counts(_ weighted: [String], weight: Int, plus rest: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for term in weighted { counts[term, default: 0] += weight }
        for term in rest { counts[term, default: 0] += 1 }
        return counts
    }
}
