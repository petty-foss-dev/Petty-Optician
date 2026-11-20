import SwiftUI

struct LessonGlossary: ViewModifier {
    let exam: ExamID
    @State private var definition: GlossaryTerm?
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "petty-glossary" else { return .systemAction }
                guard url.host == "term", let term = GlossaryLinks.byExam[exam]?.termsByID[url.lastPathComponent] else { return .discarded }
                definition = term
                return .handled
            })
            .sheet(item: $definition) { term in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(term.term)
                                .font(.system(.title, design: .serif, weight: .semibold))
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("definition.term")
                            if let aliases = term.aliases, !aliases.isEmpty {
                                Text(aliases.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            Text(term.definition).font(.body).textSelection(.enabled)
                            if let source = term.source { SourceList(sources: [source]) }
                        }
                        .frame(maxWidth: 600, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .pettyScreen()
                    .navigationTitle("Glossary")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { definition = nil }
                                .accessibilityIdentifier("definition.done")
                        }
                    }
                }
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
            }
    }
}
