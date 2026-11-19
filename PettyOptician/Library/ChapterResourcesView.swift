import SwiftData
import SwiftUI

struct ChapterResourcesView: View {
    let chapter: TextbookChapter
    @Query private var marks: [ResourceMark]
    @State private var filter = LibraryView.Filter.all
    @State private var search = ""
    @Environment(\.palette) private var palette
    private let textbook = Textbook.shared

    var body: some View {
        let favorites = Set(marks.filter(\.favorite).map(\.resourceID))
        let number = textbook.number(of: chapter)
        let all = textbook.resources(in: chapter)
        let results = all.filter { filter.matches($0, favorites: favorites) && $0.matches(search: search) }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(chapter.exam.shortLabel) · CHAPTER \(number) · WATCH & READ")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(palette.accent)
                    Text(chapter.title)
                        .font(.system(.title, design: .serif, weight: .bold))
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("Explore videos, articles, books and practice that support this chapter.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.bottom, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibraryView.Filter.allCases) { item in
                            Button { filter = item } label: { Chip(text: item.rawValue, selected: filter == item) }
                                .accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(results.count == all.count ? "\(all.count) resources" : "\(results.count) of \(all.count) resources")
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)

                if results.isEmpty {
                    if search.trimmingCharacters(in: .whitespaces).isEmpty {
                        ContentUnavailableView(
                            filter == .saved ? "Nothing saved yet" : "No \(filter.rawValue.lowercased()) for this chapter",
                            systemImage: filter == .saved ? "bookmark" : "line.3.horizontal.decrease.circle",
                            description: Text(filter == .saved ? "Bookmark a resource to keep it here." : "Choose All to see every resource for this chapter.")
                        )
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
                ForEach(results) { ResourceRow(resource: $0, showsChapterLinks: false) }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .searchable(text: $search, prompt: "Search this chapter’s resources")
        .pettyScreen()
        .navigationTitle("Chapter \(number) Resources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResourceChapterLinks: View {
    let resource: StudyResource
    var exam: ExamID?
    @Environment(\.palette) private var palette
    private let textbook = Textbook.shared

    var body: some View {
        let chapters = textbook.chapters(for: resource, exam: exam)
        if !chapters.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("READ IN THE TEXTBOOK")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(palette.secondaryText)
                ForEach(chapters) { chapter in
                    NavigationLink {
                        TextbookChapterView(chapter: chapter)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "book")
                            Text("\(chapter.exam.shortLabel) Chapter \(textbook.number(of: chapter)) · \(chapter.title)")
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(palette.tertiaryText)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("resource.chapter.\(chapter.id)")
                }
            }
        }
    }
}
