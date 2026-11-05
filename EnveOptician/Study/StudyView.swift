import SwiftData
import SwiftUI

struct StudyView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Environment(\.palette) private var palette
    @State private var query = ""
    private let library = ContentLibrary.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ExamSwitcher()
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        examHeader
                        sections
                        toolkit
                    } else {
                        SearchResultsView(query: query, exam: settings.exam)
                    }
                }
                .padding()
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(settings.exam.shortLabel): ANSI, glaucoma, tear lens…")
            .tabScreen("Study")
            .navigationDestination(for: ExamDomain.self) { GuideView(domain: $0) }
            .navigationDestination(for: GuideHit.self) { GuideView(domain: $0.domain, focus: $0.index) }
            .navigationDestination(for: TopicHit.self) { TopicView(topic: $0) }
        }
    }

    private var examHeader: some View {
        let info = library.exam(settings.exam)
        return VStack(alignment: .leading, spacing: 4) {
            Text(settings.exam == .abo ? "ABO Basic · Spectacle Dispensing" : "NCLE Basic · Contact Lens Dispensing")
                .font(.headline)
                .foregroundStyle(palette.text)
            Text([info?.totalQuestions.map { "\($0) questions" }, info?.timeMinutes.map { "\($0) min" }, "official content outline"]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.horizontal, 4)
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Exam Sections", trailing: "% of exam")
            ForEach(Array(library.domains(for: settings.exam).enumerated()), id: \.element.id) { index, domain in
                NavigationLink(value: domain) {
                    DomainGuideRow(number: index + 1, domain: domain, guide: library.guide(for: domain.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var toolkit: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Toolkit")
            NavigationLink { DiagramGalleryView() } label: {
                LinkRow(title: "Diagrams", subtitle: "\(library.diagrams(for: settings.exam).count) labeled, source-checked illustrations", symbol: "photo.on.rectangle.angled")
            }
            NavigationLink { PhotoAtlasView() } label: {
                LinkRow(title: "Photo Atlas", subtitle: "\(library.images(for: settings.exam).count) real instruments, lenses and eye conditions", symbol: "photo.stack")
            }
            NavigationLink { CalculatorsView() } label: {
                LinkRow(title: "Optics Calculators", subtitle: "Transposition, Prentice, vertex, MBS, K readings…", symbol: "function")
            }
            NavigationLink { FormulaSheetView() } label: {
                LinkRow(title: "Formula Sheet", subtitle: "Every formula from the guides in one place", symbol: "sum")
            }
            NavigationLink { ExamInfoView(exam: settings.exam) } label: {
                LinkRow(title: "About the \(settings.exam.shortLabel) Exam", subtitle: "Format, fees, content outline, registration", symbol: "info.circle")
            }
            NavigationLink { CaliforniaView() } label: {
                LinkRow(title: "California Registration", subtitle: "SLD, CLD and RDO requirements step by step", symbol: "building.columns")
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DomainGuideRow: View {
    let number: Int
    let domain: ExamDomain
    let guide: StudyGuide?
    @Environment(\.palette) private var palette
    @Query private var stats: [QuestionStat]
    private let library = ContentLibrary.shared

    var body: some View {
        let questions = library.questions(for: guide?.exam ?? .abo, domain: domain.id)
        let ids = Set(questions.map(\.id))
        let answered = stats.filter { ids.contains($0.questionID) && $0.seen > 0 }
        let accuracy = answered.isEmpty ? nil : Double(answered.filter(\.lastWasCorrect).count) / Double(answered.count)

        Panel(padding: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(number).").font(.headline.monospacedDigit()).foregroundStyle(palette.accent)
                        Text(domain.name).font(.headline).foregroundStyle(palette.text).multilineTextAlignment(.leading)
                        Spacer()
                        Text("\(Int(domain.weight))%")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(palette.accent)
                    }
                    if let guide {
                        Text(guide.summary)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 12) {
                        Label("\(guide?.sections.count ?? 0) lessons", systemImage: "text.book.closed")
                        Label("\(questions.count) questions", systemImage: "checklist")
                        Label("\(library.topics(for: guide?.exam ?? .abo, domain: domain.id).count) topics", systemImage: "tag")
                        if let accuracy {
                            Label(accuracy.formatted(.percent.precision(.fractionLength(0))), systemImage: "target")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
                }
                Image(systemName: "chevron.right").foregroundStyle(palette.tertiaryText)
            }
        }
    }
}

struct LinkRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    @Environment(\.palette) private var palette

    var body: some View {
        Panel(padding: 14) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(palette.text)
                    Text(subtitle).font(.caption).foregroundStyle(palette.secondaryText).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(palette.tertiaryText)
            }
        }
    }
}

struct GuideView: View {
    let domain: ExamDomain
    var focus: Int?
    @Environment(\.palette) private var palette
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Query private var stats: [QuestionStat]
    @State private var activeQuiz: QuizSession?
    @State private var activeDeck: FlashcardDeck?
    @State private var expanded: Set<Int>
    private let library = ContentLibrary.shared

    init(domain: ExamDomain, focus: Int? = nil) {
        self.domain = domain
        self.focus = focus
        _expanded = State(initialValue: [focus ?? 0])
    }

    var body: some View {
        let guide = library.guide(for: domain.id)
        let exam = guide?.exam ?? StudySettings.shared.exam
        let questions = library.questions(for: exam, domain: domain.id)
        let cards = library.flashcards(for: exam, domain: domain.id)
        let resources = library.resources(for: exam, domain: domain.id)

        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(domain.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.text)
                if let guide {
                    Text(guide.summary)
                        .font(.body)
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 12) {
                        Button {
                            let config = QuizConfig(exam: exam, title: domain.name, domains: [domain.id], count: 15)
                            activeQuiz = QuizSession(
                                config: config,
                                questions: QuizBuilder.weakFirst(exam: exam, domain: domain.id, count: 15, library: library, history: stats.history),
                                flagged: stats.flaggedIDs
                            )
                        } label: {
                            Label("Practice", systemImage: "checklist").frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(questions.isEmpty)

                        Button {
                            activeDeck = FlashcardDeck(title: domain.name, cards: cards.shuffled())
                        } label: {
                            Label("\(cards.count) Cards", systemImage: "rectangle.on.rectangle.angled").frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.bordered)
                        .disabled(cards.isEmpty)
                    }

                    let topics = library.topics(for: exam, domain: domain.id)
                    if !topics.isEmpty {
                        SectionTitle(title: "Topics", trailing: "\(topics.count)")
                        FlowLayout(spacing: 8) {
                            ForEach(topics, id: \.name) { topic in
                                NavigationLink {
                                    TopicView(topic: TopicHit(domain: domain, name: topic.name, count: topic.count))
                                } label: {
                                    Chip(text: "\(topic.name) · \(topic.count)")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    SectionTitle(title: "Lessons", trailing: "\(guide.sections.count)")
                    ForEach(Array(guide.sections.enumerated()), id: \.offset) { index, section in
                        sectionPanel(section, index: index).id(index)
                    }

                    if let formulas = guide.formulas, !formulas.isEmpty {
                        SectionTitle(title: "Formulas")
                        Panel {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(formulas, id: \.self) { FormulaRow(formula: $0) }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Guide coming soon", systemImage: "book", description: Text("Practice questions and flashcards are still available for this domain."))
                }

                let photos = library.images(for: exam, domain: domain.id)
                if !photos.isEmpty {
                    SectionTitle(title: "Photos", trailing: "\(photos.count)")
                    PhotoStrip(images: photos)
                }

                if !resources.isEmpty {
                    SectionTitle(title: "Watch & Read", trailing: "\(resources.count)")
                    ForEach(resources.prefix(12)) { ResourceRow(resource: $0) }
                }
            }
            .padding()
            .safeAreaPadding(.bottom, bottomBarInset)
        }
        .onAppear {
            if let focus { proxy.scrollTo(focus, anchor: .top) }
        }
        }
        .enveScreen()
        .navigationTitle(domain.name)
        .navigationBarTitleDisplayMode(.inline)
        .quizCover($activeQuiz)
        .fullScreenCover(item: $activeDeck) { FlashcardSessionView(deck: $0) }
    }

    private func sectionPanel(_ section: GuideSection, index: Int) -> some View {
        let isOpen = expanded.contains(index)
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy) {
                        if isOpen { expanded.remove(index) } else { expanded.insert(index) }
                    }
                } label: {
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(palette.accent.opacity(0.18)))
                            .foregroundStyle(palette.accent)
                        Text(section.heading)
                            .font(.headline)
                            .foregroundStyle(palette.text)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                            .foregroundStyle(palette.tertiaryText)
                    }
                }
                .buttonStyle(.plain)

                if isOpen {
                    RichText(text: section.body)
                    if let diagram = library.diagram(section.diagram) {
                        DiagramCard(diagram: diagram)
                    }
                    if let sources = section.sources, !sources.isEmpty {
                        SourceList(sources: sources)
                    }
                }
            }
        }
    }
}

struct FormulaRow: View {
    let formula: Formula
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formula.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            Text(formula.expression)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(palette.accent)
                .textSelection(.enabled)
            if let notes = formula.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(palette.secondaryText)
            }
        }
    }
}

struct FormulaSheetView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Environment(\.palette) private var palette
    @Environment(\.bottomBarInset) private var bottomBarInset
    private let library = ContentLibrary.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(library.domains(for: settings.exam)) { domain in
                    if let formulas = library.guide(for: domain.id)?.formulas, !formulas.isEmpty {
                        SectionTitle(title: domain.name)
                        Panel {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(formulas, id: \.self) { FormulaRow(formula: $0) }
                            }
                        }
                    }
                }
            }
            .padding()
            .safeAreaPadding(.bottom, bottomBarInset)
        }
        .enveScreen()
        .navigationTitle("Formula Sheet")
    }
}
