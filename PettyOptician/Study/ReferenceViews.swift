import SwiftUI

struct GlossaryView: View {
    @ObservedObject private var settings = StudySettings.shared
    @State private var query = ""
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let terms = library.glossary(for: settings.exam).filter { term in
            query.isEmpty || ([term.term] + (term.aliases ?? [])).contains { $0.localizedCaseInsensitiveContains(query) }
                || term.definition.localizedCaseInsensitiveContains(query)
        }
        let grouped = Dictionary(grouping: terms, by: \.index)

        List {
            ForEach(grouped.keys.sorted(), id: \.self) { letter in
                Section(letter) {
                    ForEach(grouped[letter] ?? []) { GlossaryRow(term: $0) }
                }
            }
        }
        .overlay {
            if terms.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a term")
        .navigationTitle("Glossary")
    }
}

struct GlossaryRow: View {
    let term: GlossaryTerm
    @State private var expanded = false
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        Button { withAnimation(.snappy) { expanded.toggle() } } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(term.term).font(.headline).foregroundStyle(palette.text)
                    if let aliases = term.aliases, !aliases.isEmpty {
                        Text(aliases.joined(separator: ", ")).font(.caption).foregroundStyle(palette.tertiaryText).lineLimit(1)
                    }
                }
                Text(term.definition)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(expanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                if expanded {
                    FlowLayout(spacing: 6) {
                        ForEach(term.domains, id: \.self) { Chip(text: library.domainName($0)) }
                    }
                    if let source = term.source { SourceList(sources: [source]) }
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

struct ReferenceTablesView: View {
    @ObservedObject private var settings = StudySettings.shared
    private let library = ContentLibrary.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(library.tables(for: settings.exam)) { table in
                    NavigationLink { ReferenceTableView(table: table) } label: {
                        LinkRow(title: table.title, subtitle: "\(table.rows.count) rows · \(table.columns.joined(separator: ", "))", symbol: "tablecells")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Reference Tables")
    }
}

struct ReferenceTableView: View {
    let table: ReferenceTable
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: true) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
                        GridRow {
                            ForEach(Array(table.columns.enumerated()), id: \.offset) { _, column in
                                Text(column.uppercased())
                                    .font(.caption.weight(.bold))
                                    .tracking(0.5)
                                    .foregroundStyle(palette.accent)
                                    .padding(.vertical, 8)
                            }
                        }
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                            Divider().gridCellUnsizedAxes(.horizontal)
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                                    Text(cell)
                                        .font(column == 0 ? .subheadline.weight(.semibold) : .subheadline)
                                        .foregroundStyle(palette.text)
                                        .frame(maxWidth: 240, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 8)
                                }
                            }
                            .background(index.isMultiple(of: 2) ? Color.clear : palette.secondaryText.opacity(0.05))
                        }
                    }
                    .padding(14)
                }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.cardBackground))

                if let notes = table.notes, !notes.isEmpty {
                    Text(notes).font(.footnote).foregroundStyle(palette.secondaryText)
                }
                if let sources = table.sources, !sources.isEmpty { SourceList(sources: sources) }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle(table.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
