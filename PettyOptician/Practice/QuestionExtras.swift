import SwiftData
import SwiftUI

/// Everything that follows an explanation once the answer is known: diagram, source, the lesson it tests, and actions.
struct QuestionExtras: View {
    let question: Question
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query private var personalCards: [PersonalCard]
    private let library = ContentLibrary.shared

    var body: some View {
        if let diagram = library.diagram(question.diagram) {
            DiagramCard(diagram: diagram, showsCaption: false)
        }
        if let source = question.source {
            SourceList(sources: [source])
        }
        if let lesson = LessonLinks.shared.lesson(for: question),
           let domain = library.domains(for: question.exam).first(where: { $0.id == lesson.domain }),
           let section = library.guide(for: lesson.domain)?.sections[lesson.index] {
            NavigationLink { GuideView(domain: domain, focus: lesson.index) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.book.closed").foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Review the lesson").font(.caption).foregroundStyle(palette.secondaryText)
                        Text(section.heading).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(palette.tertiaryText)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(palette.accent.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("question.lesson")
        }
        FlowLayout(spacing: 10) {
            let card = personalCards.first { $0.questionID == question.id }
            if question.picture == nil {
                Button {
                    if let card { card.delete(from: context) } else { context.insert(PersonalCard(question: question)) }
                    try? context.save()
                } label: {
                    Label(card == nil ? "Add to Cards" : "In My Cards", systemImage: card == nil ? "plus.rectangle.on.rectangle" : "checkmark.rectangle.stack.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("question.add-card")
            }
            if !question.isGenerated {
                NoteButton(target: .question(question))
            }
            Link(destination: ProblemReport.url(for: question)) {
                Label("Report a Problem", systemImage: "exclamationmark.bubble")
            }
            .buttonStyle(.bordered)
            .tint(palette.secondaryText)
        }
        .font(.subheadline.weight(.semibold))
        .labelStyle(.titleAndIcon)
    }
}

/// Opens a pre-filled GitHub issue so wrong or unclear questions can be fixed in the open.
enum ProblemReport {
    static let newIssueURL = URL(string: "https://github.com/petty-foss-dev/Petty-Optician/issues/new")!

    static func url(for question: Question) -> URL {
        let choices = question.choices.enumerated()
            .map { "\(String(UnicodeScalar(UInt8(65 + $0.offset)))). \($0.element)\($0.offset == question.answer ? " (marked correct)" : "")" }
            .joined(separator: "\n")
        let body = """
        **Question:** `\(question.id)` (\(question.exam.shortLabel) · \(question.topic))

        > \(question.stem)

        \(choices)

        **What's wrong?**
        <!-- Wrong answer, unclear wording, outdated fact, typo… A source link helps a lot. -->

        """
        var components = URLComponents(url: newIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "title", value: "Question \(question.id): "),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url!
    }
}
