import SwiftData
import SwiftUI

struct LibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case videos = "Videos"
        case sites = "Websites"
        case practice = "Practice"
        case books = "Books"
        case saved = "Saved"

        var id: String { rawValue }

        func matches(_ resource: StudyResource, favorites: Set<String>) -> Bool {
            switch self {
            case .all: true
            case .videos: [.video, .playlist, .channel, .course].contains(resource.kind)
            case .sites: [.website, .article, .pdf, .podcast, .app].contains(resource.kind)
            case .practice: [.practiceTest, .flashcards].contains(resource.kind)
            case .books: resource.kind == .book
            case .saved: favorites.contains(resource.id)
            }
        }
    }

    @ObservedObject private var settings = StudySettings.shared
    @Query private var marks: [ResourceMark]
    @State private var filter = Filter.all
    @State private var search = ""
    @State private var domain: String?
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let favorites = Set(marks.filter(\.favorite).map(\.resourceID))
        let results = library.resources(for: settings.exam, domain: domain).filter { resource in
            filter.matches(resource, favorites: favorites) && matchesSearch(resource)
        }

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                    ExamSwitcher()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Filter.allCases) { item in
                                Button { filter = item } label: { Chip(text: item.rawValue, selected: filter == item) }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button("All Domains") { domain = nil }
                        ForEach(library.domains(for: settings.exam)) { item in
                            Button(item.name) { domain = item.id }
                        }
                    } label: {
                        Label(domain.map(library.domainName) ?? "All Domains", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline.weight(.medium))
                    }

                    Text("\(results.count) resources")
                        .font(.footnote)
                        .foregroundStyle(palette.secondaryText)

                    if results.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                    ForEach(results) { ResourceRow(resource: $0) }
                }
                .padding()
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search videos, sites, books")
            .tabScreen("Library")
            .onChange(of: settings.exam) { domain = nil }
        }
    }

    private func matchesSearch(_ resource: StudyResource) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [resource.title, resource.author ?? "", resource.description ?? ""]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

struct ResourceRow: View {
    let resource: StudyResource
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query private var marks: [ResourceMark]
    @State private var playing = false
    @State private var browsing: URL?

    init(resource: StudyResource) {
        self.resource = resource
        let id = resource.id
        _marks = Query(filter: #Predicate<ResourceMark> { $0.resourceID == id })
    }

    private var mark: ResourceMark? { marks.first }

    var body: some View {
        Panel(padding: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    if resource.embedURL != nil { playing = true } else { browsing = resource.url }
                    markCompleted()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        thumbnail
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resource.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                            HStack(spacing: 6) {
                                Label(resource.kind.label, systemImage: resource.kind.symbol)
                                    .labelStyle(.titleAndIcon)
                                    .fixedSize()
                                if let minutes = resource.minutes { Text("· \(minutes) min").fixedSize() }
                                if let author = resource.author { Text("· \(author)").lineLimit(1) }
                            }
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                            if let description = resource.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(palette.tertiaryText)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            if resource.embedURL != nil {
                                Label("Plays in app", systemImage: "play.circle")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                            } else if resource.free == false {
                                Text("Paid").font(.caption2.weight(.bold)).foregroundStyle(palette.accent)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 14) {
                    Button(action: toggleFavorite) {
                        Image(systemName: mark?.favorite == true ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(mark?.favorite == true ? "Remove from saved" : "Save")
                    if mark?.completed == true {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            .accessibilityLabel("Opened")
                    }
                }
                .foregroundStyle(palette.accent)
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $playing) {
            if let embed = resource.embedURL {
                VideoPlayerView(resource: resource, embedURL: embed)
            }
        }
        .inAppBrowser($browsing)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = resource.thumbnailURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(16 / 9, contentMode: .fill)
            } placeholder: {
                placeholderIcon
            }
            .frame(width: 112, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
        } else {
            placeholderIcon.frame(width: 48, height: 48)
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(palette.accent.opacity(0.15))
            .overlay {
                Image(systemName: resource.kind.symbol).foregroundStyle(palette.accent)
            }
    }

    private func resolvedMark() -> ResourceMark {
        if let mark { return mark }
        let created = ResourceMark(resourceID: resource.id)
        context.insert(created)
        return created
    }

    private func toggleFavorite() {
        let target = resolvedMark()
        target.favorite.toggle()
        try? context.save()
    }

    private func markCompleted() {
        resolvedMark().completed = true
        try? context.save()
    }
}
