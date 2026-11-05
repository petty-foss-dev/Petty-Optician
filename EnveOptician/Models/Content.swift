import Foundation

enum ExamID: String, Codable, CaseIterable, Identifiable, Sendable {
    case abo
    case ncle

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .abo: "ABO"
        case .ncle: "NCLE"
        }
    }

    var subject: String {
        switch self {
        case .abo: "Spectacles"
        case .ncle: "Contact Lenses"
        }
    }
}

struct ExamDomain: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let weight: Double
}

struct OfficialOutlineDomain: Codable, Hashable, Sendable {
    let name: String
    let weight: Double?
    let subtopics: [String]?
}

struct Exam: Codable, Identifiable, Sendable {
    let id: ExamID
    let shortName: String
    let name: String
    let administrator: String?
    let totalQuestions: Int?
    let scoredQuestions: Int?
    let timeMinutes: Int?
    let fee: String?
    let delivery: String?
    let scoring: String?
    let eligibility: String?
    let retakePolicy: String?
    let registrationURL: URL?
    let contentOutlineURL: URL?
    let officialOutline: [OfficialOutlineDomain]?
    let domains: [ExamDomain]
    let notes: [String]?
}

struct Question: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let exam: ExamID
    let domain: String
    let topic: String
    let difficulty: Int
    let stem: String
    let choices: [String]
    let answer: Int
    let explanation: String
    let source: SourceLink?
    let diagram: String?
}

struct Flashcard: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let exam: ExamID
    let domain: String
    let front: String
    let back: String
}

struct GuideSection: Codable, Hashable, Sendable {
    let heading: String
    let body: String
    let diagram: String?
    let sources: [SourceLink]?
}

struct Formula: Codable, Hashable, Sendable {
    let name: String
    let expression: String
    let notes: String?
}

struct StudyGuide: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let exam: ExamID
    let domain: String
    let title: String
    let summary: String
    let sections: [GuideSection]
    let formulas: [Formula]?

    /// Packs may add sections to an existing guide; the first guide for a domain keeps its title and summary.
    func merged(with other: StudyGuide) -> StudyGuide {
        StudyGuide(
            id: id, exam: exam, domain: domain, title: title,
            summary: summary.isEmpty ? other.summary : summary,
            sections: sections + other.sections,
            formulas: (formulas ?? []) + (other.formulas ?? []).filter { f in !(formulas ?? []).contains { $0.name == f.name } }
        )
    }
}

struct ImageInfo: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let file: String
    let title: String
    let caption: String
    let author: String
    let license: String
    let licenseURL: URL?
    let sourceURL: URL
    let credit: String
    let exams: [ExamID]
    let domains: [String]

    var url: URL? {
        let parts = file.split(separator: ".", maxSplits: 1).map(String.init)
        return Bundle.main.url(forResource: parts[0], withExtension: parts.count > 1 ? parts[1] : nil)
    }
}

struct DiagramInfo: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let caption: String
    let exams: [ExamID]
    let domains: [String]
    let sources: [SourceLink]?
}

enum ResourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case video, playlist, channel, website, article, pdf, book, practiceTest, flashcards, podcast, app, course

    var id: String { rawValue }

    var label: String {
        switch self {
        case .video: "Video"
        case .playlist: "Playlist"
        case .channel: "Channel"
        case .website: "Website"
        case .article: "Article"
        case .pdf: "PDF"
        case .book: "Book"
        case .practiceTest: "Practice Test"
        case .flashcards: "Flashcards"
        case .podcast: "Podcast"
        case .app: "App"
        case .course: "Course"
        }
    }

    var symbol: String {
        switch self {
        case .video: "play.rectangle.fill"
        case .playlist: "list.and.film"
        case .channel: "person.crop.square.filled.and.at.rectangle"
        case .website: "globe"
        case .article: "doc.text"
        case .pdf: "doc.richtext"
        case .book: "book.closed"
        case .practiceTest: "checklist"
        case .flashcards: "rectangle.on.rectangle.angled"
        case .podcast: "headphones"
        case .app: "apps.iphone"
        case .course: "graduationcap"
        }
    }
}

struct StudyResource: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
    let kind: ResourceKind
    let exams: [ExamID]
    let domains: [String]?
    let author: String?
    let description: String?
    let free: Bool?
    let minutes: Int?

    var youTubeID: String? {
        guard kind == .video, let host = url.host() else { return nil }
        if host.contains("youtu.be") { return url.pathComponents.dropFirst().first }
        guard host.contains("youtube.com") else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "v" }?.value
    }

    var thumbnailURL: URL? {
        youTubeID.flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/mqdefault.jpg") }
    }
}

struct CaliforniaCredential: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let agency: String?
    let requiredExam: ExamID?
    let requirements: [String]?
    let fee: String?
    let renewal: String?
    let url: URL?
    let codeSections: [String]?
}

struct CaliforniaStep: Codable, Hashable, Sendable {
    let title: String
    let detail: String
    let url: URL?
}

struct FAQEntry: Codable, Hashable, Sendable {
    let q: String
    let a: String
}

struct SourceLink: Codable, Hashable, Sendable {
    let title: String
    let url: URL
}

struct CaliforniaGuide: Codable, Sendable {
    let summary: String
    let credentials: [CaliforniaCredential]
    let steps: [CaliforniaStep]
    let faq: [FAQEntry]?
    let sources: [SourceLink]?
    let lastVerified: String?
}
