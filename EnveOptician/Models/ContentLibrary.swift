import Foundation

/// Bundled content is discovered by filename prefix, so new packs (e.g. `questions_mynotes.json`) load without code changes.
struct ContentLibrary: Sendable {
    let exams: [Exam]
    let questions: [Question]
    let flashcards: [Flashcard]
    let guides: [StudyGuide]
    let resources: [StudyResource]
    let diagrams: [DiagramInfo]
    let images: [ImageInfo]
    let california: CaliforniaGuide

    private let domainNames: [String: String]

    static let shared: ContentLibrary = {
        do {
            return try load(from: .main)
        } catch {
            fatalError("Bundled content failed to load: \(error)")
        }
    }()

    init(
        exams: [Exam],
        questions: [Question],
        flashcards: [Flashcard],
        guides: [StudyGuide],
        resources: [StudyResource],
        diagrams: [DiagramInfo],
        images: [ImageInfo],
        california: CaliforniaGuide
    ) {
        self.exams = exams
        self.questions = questions
        self.flashcards = flashcards
        var merged: [String: StudyGuide] = [:]
        for guide in guides {
            merged[guide.domain] = merged[guide.domain].map { $0.merged(with: guide) } ?? guide
        }
        let order = exams.flatMap(\.domains).map(\.id)
        self.guides = merged.values.sorted { (order.firstIndex(of: $0.domain) ?? .max) < (order.firstIndex(of: $1.domain) ?? .max) }
        self.resources = resources
        self.diagrams = diagrams
        self.images = images
        self.california = california
        domainNames = Dictionary(
            exams.flatMap(\.domains).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static func load(from bundle: Bundle) throws -> ContentLibrary {
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder()

        func decode<T: Decodable>(_ type: T.Type, file: URL) throws -> T {
            do {
                return try decoder.decode(type, from: Data(contentsOf: file))
            } catch {
                throw ContentError.invalidFile(file.lastPathComponent, error)
            }
        }

        func all<T: Decodable>(_ prefix: String, as type: T.Type) throws -> [T] {
            try urls.filter { $0.lastPathComponent.hasPrefix(prefix) }
                .flatMap { try decode([T].self, file: $0) }
        }

        func single(_ name: String) throws -> URL {
            guard let url = urls.first(where: { $0.lastPathComponent == name }) else {
                throw ContentError.missingFile(name)
            }
            return url
        }

        return try ContentLibrary(
            exams: decode([Exam].self, file: single("exams.json")),
            questions: all("questions_", as: Question.self),
            flashcards: all("flashcards_", as: Flashcard.self),
            guides: all("guides_", as: StudyGuide.self),
            resources: all("resources_", as: StudyResource.self),
            diagrams: decode([DiagramInfo].self, file: single("diagrams.json")),
            images: decode([ImageInfo].self, file: single("images.json")),
            california: decode(CaliforniaGuide.self, file: single("california.json"))
        )
    }

    func exam(_ id: ExamID) -> Exam? { exams.first { $0.id == id } }

    func domains(for exam: ExamID) -> [ExamDomain] { self.exam(exam)?.domains ?? [] }

    func domainName(_ id: String) -> String { domainNames[id] ?? id }

    func questions(for exam: ExamID, domain: String? = nil) -> [Question] {
        questions.filter { $0.exam == exam && (domain == nil || $0.domain == domain) }
    }

    func flashcards(for exam: ExamID, domain: String? = nil) -> [Flashcard] {
        flashcards.filter { $0.exam == exam && (domain == nil || $0.domain == domain) }
    }

    func guide(for domain: String) -> StudyGuide? { guides.first { $0.domain == domain } }

    func diagram(_ id: String?) -> DiagramInfo? { id.flatMap { id in diagrams.first { $0.id == id } } }

    func diagrams(for exam: ExamID, domain: String? = nil) -> [DiagramInfo] {
        diagrams.filter { $0.exams.contains(exam) && (domain.map($0.domains.contains) ?? true) }
    }

    func images(for exam: ExamID, domain: String? = nil) -> [ImageInfo] {
        images.filter { $0.exams.contains(exam) && (domain.map($0.domains.contains) ?? true) }
    }

    func topics(for exam: ExamID, domain: String) -> [(name: String, count: Int)] {
        Dictionary(grouping: questions(for: exam, domain: domain), by: \.topic)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func resources(for exam: ExamID?, domain: String? = nil) -> [StudyResource] {
        resources.filter { resource in
            (exam.map { resource.exams.contains($0) } ?? true)
                && (domain.map { resource.domains?.contains($0) == true } ?? true)
        }
    }
}

enum ContentError: Error, CustomStringConvertible {
    case missingFile(String)
    case invalidFile(String, Error)

    var description: String {
        switch self {
        case .missingFile(let name): "Missing \(name)"
        case .invalidFile(let name, let error): "\(name): \(error)"
        }
    }
}
