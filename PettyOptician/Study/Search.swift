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
    var terms: [GlossaryTerm] = []
    var tables: [ReferenceTable] = []

    var isEmpty: Bool {
        topics.isEmpty && sections.isEmpty && questions.isEmpty && flashcards.isEmpty && resources.isEmpty
            && diagrams.isEmpty && images.isEmpty && terms.isEmpty && tables.isEmpty
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
        results.terms = glossary(for: exam).filter {
            Self.matches(([$0.term] + ($0.aliases ?? [])).joined(separator: " ") + " " + $0.definition, terms)
        }
        results.tables = tables(for: exam).filter {
            Self.matches($0.title + " " + $0.columns.joined(separator: " ") + " " + $0.rows.joined().joined(separator: " "), terms)
        }
        return results
    }
}

struct SearchResultsView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case all = "All", notes = "My Notes", lessons = "Lessons", questions = "Questions", glossary = "Glossary", tables = "Tables", cards = "Cards", media = "Media"
        var id: String { rawValue }
    }

    let query: String
    let exam: ExamID
    var topicQuestions: [Question]?
    @Environment(\.palette) private var palette
    @Query private var stats: [QuestionStat]
    @Query(sort: \StudyNote.updated, order: .reverse) private var notes: [StudyNote]
    @State private var kind: Kind
    @State private var status = QuizConfig.Source.all
    @State private var section: String?
    @State private var expandedKinds: Set<String> = []
    @State private var activeQuiz: QuizSession?
    private let library = ContentLibrary.shared

    init(query: String, exam: ExamID, topicQuestions: [Question]? = nil, kind: Kind = .all) {
        self.query = query
        self.exam = exam
        self.topicQuestions = topicQuestions
        _kind = State(initialValue: kind)
    }

    var body: some View {
        let results = library.search(query, exam: exam)
        let allQuestions = topicQuestions ?? results.questions
        let history = stats.history
        let questions = kind == .questions
            ? allQuestions.filter { (section == nil || $0.domain == section) && QuizBuilder.matches(status, history[$0.id]) }
            : allQuestions
        let terms = query.lowercased().split(separator: " ").map(String.init)
        let matchingNotes = topicQuestions == nil
            ? notes.filter { note in note.exam == exam && terms.allSatisfy { note.text.lowercased().contains($0) } }
            : []
        let counts: [Kind: Int] = [
            .notes: matchingNotes.count,
            .lessons: results.sections.count + results.topics.count,
            .questions: allQuestions.count,
            .glossary: results.terms.count,
            .tables: results.tables.count,
            .cards: results.flashcards.count,
            .media: results.diagrams.count + results.images.count + results.resources.count
        ]
        let shows = { (k: Kind) in kind == .all || kind == k }

        LazyVStack(alignment: .leading, spacing: 12) {
            if results.isEmpty && allQuestions.isEmpty && matchingNotes.isEmpty {
                ContentUnavailableView.search(text: query)
            } else if topicQuestions == nil {
                FlowLayout(spacing: 8) {
                    Button { kind = .all } label: { Chip(text: "All", selected: kind == .all) }
                    ForEach(Kind.allCases.dropFirst().filter { counts[$0, default: 0] > 0 }) { option in
                        Button { kind = option } label: { Chip(text: "\(option.rawValue) · \(counts[option, default: 0])", selected: kind == option) }
                            .accessibilityIdentifier("search.kind.\(option.rawValue.lowercased())")
                    }
                }
                .buttonStyle(.plain)
            }
            if shows(.notes) {
                group("My Notes", "notes", matchingNotes, limit: 3) { NoteRow(note: $0) }
            }
            if shows(.lessons), topicQuestions == nil, !results.topics.isEmpty {
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
            if shows(.glossary) {
                group("Glossary", "terms", results.terms, limit: 3) { term in
                    Panel(padding: 14) { GlossaryRow(term: term) }
                }
            }
            if shows(.tables) {
                group("Reference Tables", "tables", results.tables, limit: 3) { table in
                    NavigationLink { ReferenceTableView(table: table) } label: {
                        LinkRow(title: table.title, subtitle: table.columns.joined(separator: " · "), symbol: "tablecells")
                    }
                    .buttonStyle(.plain)
                }
            }
            if shows(.lessons) {
                group("Study Guide", "sections", results.sections) { hit in
                    NavigationLink(value: hit) { SectionHitRow(hit: hit) }.buttonStyle(.plain)
                }
            }
            if shows(.media) {
                group("Diagrams", "diagrams", results.diagrams, limit: 3) { diagram in
                    Panel { DiagramCard(diagram: diagram) }
                }
                if !results.images.isEmpty {
                    SectionTitle(title: "Photos", trailing: "\(results.images.count)")
                    PhotoStrip(images: results.images)
                }
            }
            if shows(.questions), !allQuestions.isEmpty {
                questionFilters(allQuestions, history: history, matching: questions)
                group("Questions", "questions", questions) { QuestionPreviewRow(question: $0) }
            }
            if shows(.cards) {
                group("Flashcards", "cards", results.flashcards) { FlashcardPreviewRow(card: $0) }
            }
            if shows(.media) {
                group("Videos & Resources", "resources", results.resources) { ResourceRow(resource: $0) }
            }
        }
        .quizCover($activeQuiz)
        .onChange(of: query) { section = nil }
    }

    /// Status and section filters plus a one-tap quiz over whatever is left.
    @ViewBuilder
    private func questionFilters(_ all: [Question], history: [String: QuestionHistory], matching: [Question]) -> some View {
        if kind == .questions {
            FlowLayout(spacing: 8) {
                ForEach(QuizConfig.Source.allCases) { option in
                    let n = all.filter { (section == nil || $0.domain == section) && QuizBuilder.matches(option, history[$0.id]) }.count
                    Button { status = option } label: { Chip(text: option == .all ? "Any · \(n)" : "\(option.label) · \(n)", selected: status == option) }
                        .accessibilityIdentifier("search.status.\(option.rawValue)")
                }
            }
            .buttonStyle(.plain)
            let domains = library.domains(for: exam).filter { domain in all.contains { $0.domain == domain.id } }
            if domains.count > 1 {
                FlowLayout(spacing: 8) {
                    Button { section = nil } label: { Chip(text: "All sections", selected: section == nil) }
                    ForEach(domains) { domain in
                        let n = all.filter { $0.domain == domain.id && QuizBuilder.matches(status, history[$0.id]) }.count
                        Button { section = domain.id } label: { Chip(text: "\(domain.name) · \(n)", selected: section == domain.id) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        if topicQuestions == nil, !matching.isEmpty {
            Button {
                let picked = QuizBuilder.weakFirst(matching, count: min(matching.count, 30), history: history)
                activeQuiz = QuizSession(
                    config: QuizConfig(exam: exam, title: "“\(query)”", count: picked.count),
                    questions: picked,
                    flagged: stats.flaggedIDs
                )
            } label: {
                Label("Practice \(min(matching.count, 30)) of These", systemImage: "checklist").frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("search.practice")
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
            let limit = kind == .all ? limit : max(limit, 20)
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
        .pettyScreen()
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .quizCover($activeQuiz)
    }
}
