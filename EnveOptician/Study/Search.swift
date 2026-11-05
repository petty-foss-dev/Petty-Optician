import SwiftData
import SwiftUI

struct GuideHit: Identifiable, Hashable {
    let domain: ExamDomain
    let index: Int
    let section: GuideSection
    var id: String { "\(domain.id)#\(index)" }
}

struct TopicHit: Identifiable, Hashable {
    let domain: ExamDomain
    let name: String
    let count: Int
    var id: String { "\(domain.id)#\(name)" }
}

struct SearchResults {
    var topics: [TopicHit] = []
    var sections: [GuideHit] = []
    var questions: [Question] = []
    var flashcards: [Flashcard] = []
    var resources: [StudyResource] = []
    var diagrams: [DiagramInfo] = []
    var images: [ImageInfo] = []

    var isEmpty: Bool {
        topics.isEmpty && sections.isEmpty && questions.isEmpty && flashcards.isEmpty && resources.isEmpty && diagrams.isEmpty && images.isEmpty
    }
}

extension ContentLibrary {
    private static let synonyms: [String: [String]] = [
        "diagnosis": ["disease", "pathology", "condition", "symptom", "diagnos"],
        "diagnose": ["disease", "pathology", "condition", "symptom", "diagnos"],
        "disease": ["pathology", "condition", "disorder"],
        "pathology": ["disease", "condition"],
        "ansi": ["z80", "z87", "ansi"],
        "standards": ["ansi", "z80", "z87", "standard", "tolerance"],
        "law": ["regulation", "rule", "ftc", "fda", "california", "hipaa", "statute"],
        "laws": ["regulation", "rule", "ftc", "fda", "california", "hipaa", "statute"],
        "rgp": ["gas permeable", "rigid", "rgp", "gp lens"],
        "gp": ["gas permeable", "rigid", "rgp"],
        "pd": ["pupillary distance", "pd"],
        "pal": ["progressive", "pal"],
        "progressives": ["progressive"],
        "bifocal": ["bifocal", "seg", "flat-top", "executive"],
        "complication": ["complication", "keratitis", "gpc", "clare", "edema", "infiltrate", "neovascular"],
        "complications": ["complication", "keratitis", "gpc", "clare", "edema", "infiltrate", "neovascular"]
    ]

    private static func terms(_ query: String) -> [[String]] {
        query.lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { [$0] + (synonyms[$0] ?? []) }
    }

    private static func matches(_ text: String, _ terms: [[String]]) -> Bool {
        terms.allSatisfy { alternatives in
            alternatives.contains { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    func search(_ query: String, exam: ExamID) -> SearchResults {
        let terms = Self.terms(query)
        guard !terms.isEmpty else { return SearchResults() }
        let domains = self.domains(for: exam)
        var results = SearchResults()

        for domain in domains {
            results.topics += topics(for: exam, domain: domain.id)
                .filter { Self.matches($0.name, terms) }
                .map { TopicHit(domain: domain, name: $0.name, count: $0.count) }
            if let guide = guide(for: domain.id) {
                results.sections += guide.sections.enumerated()
                    .filter { Self.matches($0.element.heading + " " + $0.element.body, terms) }
                    .map { GuideHit(domain: domain, index: $0.offset, section: $0.element) }
            }
        }
        results.questions = questions(for: exam).filter {
            Self.matches([$0.topic, $0.stem, $0.choices.joined(separator: " "), $0.explanation].joined(separator: " "), terms)
        }
        results.flashcards = flashcards(for: exam).filter { Self.matches($0.front + " " + $0.back, terms) }
        results.resources = resources(for: exam).filter {
            Self.matches([$0.title, $0.author ?? "", $0.description ?? ""].joined(separator: " "), terms)
        }
        results.diagrams = diagrams(for: exam).filter { Self.matches($0.title + " " + $0.caption, terms) }
        results.images = images(for: exam).filter { Self.matches($0.title + " " + $0.caption, terms) }
        return results
    }
}

struct SearchResultsView: View {
    let query: String
    let exam: ExamID
    var topicQuestions: [Question]?
    @Environment(\.palette) private var palette
    @State private var expandedKinds: Set<String> = []
    private let library = ContentLibrary.shared

    var body: some View {
        let results = library.search(query, exam: exam)
        let questions = topicQuestions ?? results.questions

        LazyVStack(alignment: .leading, spacing: 12) {
            if results.isEmpty && questions.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            if topicQuestions == nil, !results.topics.isEmpty {
                SectionTitle(title: "Topics", trailing: "\(results.topics.count)")
                FlowLayout(spacing: 8) {
                    ForEach(results.topics) { topic in
                        NavigationLink(value: topic) {
                            Chip(text: "\(topic.name) · \(topic.count)", symbol: "tag")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            group("Study Guide", "sections", results.sections) { hit in
                NavigationLink(value: hit) { SectionHitRow(hit: hit) }.buttonStyle(.plain)
            }
            group("Diagrams", "diagrams", results.diagrams, limit: 3) { diagram in
                Panel { DiagramCard(diagram: diagram) }
            }
            if !results.images.isEmpty {
                SectionTitle(title: "Photos", trailing: "\(results.images.count)")
                PhotoStrip(images: results.images)
            }
            group("Questions", "questions", questions) { QuestionPreviewRow(question: $0) }
            group("Flashcards", "cards", results.flashcards) { FlashcardPreviewRow(card: $0) }
            group("Videos & Resources", "resources", results.resources) { ResourceRow(resource: $0) }
        }
    }

    @ViewBuilder
    private func group<Item: Identifiable, Row: View>(
        _ title: String,
        _ key: String,
        _ items: [Item],
        limit: Int = 5,
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !items.isEmpty {
            let showAll = expandedKinds.contains(key)
            SectionTitle(title: title, trailing: "\(items.count)")
            ForEach(Array(items.prefix(showAll ? items.count : limit))) { row($0) }
            if items.count > limit {
                Button(showAll ? "Show fewer" : "Show all \(items.count)") {
                    withAnimation(.snappy) {
                        if showAll { expandedKinds.remove(key) } else { expandedKinds.insert(key) }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct SectionHitRow: View {
    let hit: GuideHit
    @Environment(\.palette) private var palette

    var body: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.domain.name.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(palette.accent)
                Text(hit.section.heading).font(.headline).foregroundStyle(palette.text)
                Text(hit.section.body.replacingOccurrences(of: "**", with: ""))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
        }
    }
}

struct QuestionPreviewRow: View {
    let question: Question
    @State private var revealed = false
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Chip(text: question.topic)
                    Spacer()
                    DifficultyDots(level: question.difficulty)
                }
                Text(question.stem).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    let correct = revealed && index == question.answer
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(UnicodeScalar(UInt8(65 + index)))).font(.caption.weight(.bold))
                        Text(choice).font(.subheadline)
                        Spacer(minLength: 0)
                        if correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    }
                    .foregroundStyle(correct ? Color.green : palette.text)
                }
                if revealed {
                    RichText(text: question.explanation).font(.subheadline)
                    QuestionExtras(question: question)
                }
                Button(revealed ? "Hide answer" : "Show answer") {
                    withAnimation(.snappy) { revealed.toggle() }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }
}

/// Diagram and source that follow an explanation once the answer is known.
struct QuestionExtras: View {
    let question: Question
    private let library = ContentLibrary.shared

    var body: some View {
        if let diagram = library.diagram(question.diagram) {
            DiagramCard(diagram: diagram, showsCaption: false)
        }
        if let source = question.source {
            SourceList(sources: [source])
        }
    }
}

private struct FlashcardPreviewRow: View {
    let card: Flashcard
    @State private var flipped = false
    @Environment(\.palette) private var palette

    var body: some View {
        Button { withAnimation(.snappy) { flipped.toggle() } } label: {
            Panel(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.front).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                    if flipped {
                        Divider()
                        RichText(text: card.back).font(.subheadline)
                    } else {
                        Text("Tap to flip").font(.caption).foregroundStyle(palette.tertiaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct TopicView: View {
    let topic: TopicHit
    @ObservedObject private var settings = StudySettings.shared
    @Query private var stats: [QuestionStat]
    @Environment(\.palette) private var palette
    @Environment(\.bottomBarInset) private var bottomBarInset
    @State private var activeQuiz: QuizSession?
    private let library = ContentLibrary.shared

    var body: some View {
        let questions = library.questions(for: settings.exam, domain: topic.domain.id).filter { $0.topic == topic.name }
        let ids = Set(questions.map(\.id))
        let answered = stats.filter { ids.contains($0.questionID) && $0.seen > 0 }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(topic.domain.name.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(palette.accent)
                        Text(topic.name).font(.title2.weight(.bold))
                        Text("\(questions.count) questions · \(answered.filter(\.lastWasCorrect).count) answered correctly")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                        Button {
                            activeQuiz = QuizSession(
                                config: QuizConfig(exam: settings.exam, title: topic.name, domains: [topic.domain.id], count: questions.count),
                                questions: questions.shuffled(),
                                flagged: stats.flaggedIDs
                            )
                        } label: {
                            Label("Practice This Topic", systemImage: "checklist").frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(questions.isEmpty)
                    }
                }
                SearchResultsView(query: topic.name, exam: settings.exam, topicQuestions: questions)
            }
            .padding()
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .quizCover($activeQuiz)
    }
}
