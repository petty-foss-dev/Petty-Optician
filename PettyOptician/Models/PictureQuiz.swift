import Foundation

/// "What does this show?" questions built from the bundled photos and diagrams, with wrong answers drawn
/// from the same exam section first so the choices are close calls.
enum PictureQuiz {
    static let idPrefix = "pic-"

    struct Item: Sendable {
        let id: String
        let title: String
        let caption: String
        let domains: [String]
        let isPhoto: Bool
    }

    /// Pictures of the same thing; never offered as each other's wrong answers.
    private static let sameSubject: [Set<String>] = [
        ["img-lens-clock", "img-lens-clock-diagram"],
        ["img-progressive-lens", "img-progressive-zones", "pal-layout"],
        ["img-keratoconus-topography", "img-munson-sign"],
        ["img-eye-cross-section", "img-eye-chambers", "eye-anatomy"],
        ["img-soft-lens", "img-soft-lens-on-eye"],
        ["img-bifocal", "img-executive-bifocal", "multifocals"],
        ["img-fluorescein-staining", "fluorescein-patterns"],
        ["img-cl-corneal-ulcer", "img-acanthamoeba-keratitis"],
    ]

    static func items(for exam: ExamID, library: ContentLibrary) -> [Item] {
        library.images(for: exam).map { Item(id: $0.id, title: $0.title, caption: $0.caption, domains: $0.domains, isPhoto: true) }
            + library.diagrams(for: exam).map { Item(id: $0.id, title: $0.title, caption: $0.caption, domains: $0.domains, isPhoto: false) }
    }

    static func questions(exam: ExamID, count: Int, library: ContentLibrary) -> [Question] {
        let pool = items(for: exam, library: library)
        return pool.shuffled().prefix(count).compactMap { question(for: $0, exam: exam, pool: pool) }
    }

    static func question(for item: Item, exam: ExamID, pool: [Item]) -> Question? {
        let related = sameSubject.first { $0.contains(item.id) } ?? [item.id]
        let candidates = pool.filter { !related.contains($0.id) && $0.title != item.title }
        let close = candidates.filter { !Set($0.domains).isDisjoint(with: item.domains) }.shuffled()
        let rest = candidates.filter { Set($0.domains).isDisjoint(with: item.domains) }.shuffled()
        let distractors = Array((close + rest).prefix(3))
        guard distractors.count == 3 else { return nil }
        let choices = (distractors.map(\.title) + [item.title]).shuffled()
        return Question(
            id: idPrefix + item.id,
            exam: exam,
            domain: item.domains.first { $0.hasPrefix(exam.rawValue) } ?? item.domains[0],
            topic: item.isPhoto ? "Photo ID" : "Diagram ID",
            difficulty: 1,
            stem: item.isPhoto ? "What does this photo show?" : "Which concept does this diagram illustrate?",
            choices: choices,
            answer: choices.firstIndex(of: item.title)!,
            explanation: item.caption,
            source: nil,
            diagram: nil,
            picture: item.id
        )
    }
}
