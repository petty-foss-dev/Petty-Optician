import Foundation

struct OutlineStudy: Sendable {
    struct Topic: Sendable {
        let lessons: [TextbookLesson]
        let example: Question
        let checks: [Question]
    }

    private struct Entry: Decodable {
        let lessons: [String]
        let example: String
        let checks: [String]
    }

    enum Invalid: Error {
        case missingObjective(String)
        case invalidReference(String)
    }

    static let shared: OutlineStudy = {
        do {
            return try load(from: .main, library: .shared, textbook: .shared)
        } catch {
            fatalError("Invalid outline study guide: \(error)")
        }
    }()

    private let topics: [ExamID: [String: Topic]]

    func topic(_ name: String, exam: ExamID) -> Topic? { topics[exam]?[name] }

    static func load(from bundle: Bundle, library: ContentLibrary, textbook: Textbook) throws -> Self {
        guard let url = bundle.url(forResource: "outline-study", withExtension: "json") else {
            throw ContentError.missingFile("outline-study.json")
        }
        let entries = try JSONDecoder().decode([String: [String: Entry]].self, from: Data(contentsOf: url))
        let lessons = Dictionary(uniqueKeysWithValues: ExamID.allCases.flatMap { textbook.lessons(for: $0) }.map { ($0.id, $0) })
        var topics: [ExamID: [String: Topic]] = [:]
        for exam in library.exams {
            let names = exam.officialOutline?.flatMap { $0.subtopics ?? [] } ?? []
            let examEntries = entries[exam.id.rawValue] ?? [:]
            guard Set(names) == Set(examEntries.keys) else { throw Invalid.missingObjective(exam.id.rawValue) }
            for (name, entry) in examEntries {
                let readings = entry.lessons.compactMap { lessons[$0] }
                let checks = entry.checks.compactMap { library.question(id: $0) }
                guard !readings.isEmpty, readings.count == entry.lessons.count,
                      Set(entry.lessons).count == readings.count,
                      let example = library.question(id: entry.example), example.exam == exam.id,
                      !checks.isEmpty, checks.count == entry.checks.count,
                      checks.allSatisfy({ $0.exam == exam.id }),
                      Set(entry.checks + [entry.example]).count == checks.count + 1 else {
                    throw Invalid.invalidReference(name)
                }
                topics[exam.id, default: [:]][name] = Topic(lessons: readings, example: example, checks: checks)
            }
        }
        return Self(topics: topics)
    }
}
