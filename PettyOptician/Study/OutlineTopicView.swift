import SwiftData
import SwiftUI

struct OutlineTopicView: View {
    let exam: ExamID
    let title: String
    let topic: OutlineStudy.Topic
    @Environment(\.palette) private var palette
    @Query private var stats: [QuestionStat]
    @State private var showSolution = false
    @State private var quiz: QuizSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                SectionTitle(title: "Read in the textbook")
                Panel {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(topic.lessons) { lesson in
                            let chapter = Textbook.shared.chapter(for: lesson)
                            NavigationLink {
                                TextbookReaderView(exam: chapter.exam, lesson: lesson)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(chapter.exam.shortLabel) · Chapter \(lesson.chapterNumber) · Lesson \(lesson.number)")
                                            .font(.caption).foregroundStyle(palette.secondaryText)
                                        Text(lesson.section.heading)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(palette.text)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(palette.tertiaryText)
                                }
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("outline.lesson.\(lesson.id)")
                            if lesson.id != topic.lessons.last?.id { Divider() }
                        }
                    }
                }

                SectionTitle(title: "Worked example")
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        if let diagram = ContentLibrary.shared.diagram(topic.example.diagram) {
                            DiagramCard(diagram: diagram)
                        }
                        Text(topic.example.stem)
                        ForEach(Array(topic.example.choices.enumerated()), id: \.offset) { index, choice in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1).").monospacedDigit()
                                Text(choice)
                            }
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .accessibilityElement(children: .combine)
                        }
                        DisclosureGroup("Solution", isExpanded: $showSolution) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(topic.example.choices[topic.example.answer])
                                    .font(.headline)
                                Text(topic.example.explanation)
                                if let source = topic.example.source {
                                    SourceList(sources: [source])
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                    }
                }

                Button {
                    quiz = QuizSession(
                        config: QuizConfig(exam: exam, title: title, count: topic.checks.count),
                        questions: topic.checks, flagged: stats.flaggedIDs
                    )
                } label: {
                    Label(topic.checks.count == 1 ? "Try 1 practice question" : "Try \(topic.checks.count) practice questions", systemImage: "checklist")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("outline.practice")
            }
            .padding()
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .pettyScreen()
        .navigationTitle("\(exam.shortLabel) objective")
        .navigationBarTitleDisplayMode(.inline)
        .quizCover($quiz)
    }
}
