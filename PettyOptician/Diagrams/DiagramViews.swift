import SwiftUI

struct DiagramCanvas: View {
    let id: String
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, size in
            DiagramArt.draw(id, in: Sketch(ctx: context, size: size, palette: palette))
        }
        .aspectRatio(DiagramArt.aspectRatio(id), contentMode: .fit)
    }
}

struct DiagramCard: View {
    let diagram: DiagramInfo
    var showsCaption = true
    @State private var expanded = false
    @Environment(\.palette) private var palette

    var body: some View {
        Button { expanded = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(diagram.title, systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(palette.tertiaryText)
                }
                DiagramCanvas(id: diagram.id)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.background.opacity(0.6)))
                if showsCaption {
                    Text(diagram.caption)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Diagram: \(diagram.title)")
        .sheet(isPresented: $expanded) { DiagramDetailView(diagram: diagram) }
    }
}

struct DiagramDetailView: View {
    let diagram: DiagramInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DiagramCanvas(id: diagram.id)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.background.opacity(0.7)))
                        .scaleEffect(zoom * pinch)
                        .gesture(
                            MagnifyGesture()
                                .updating($pinch) { value, state, _ in state = value.magnification }
                                .onEnded { zoom = min(3, max(1, zoom * $0.magnification)) }
                        )
                        .onTapGesture(count: 2) { withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 2 } }
                        .zIndex(1)

                    Text(diagram.caption).font(.body).foregroundStyle(palette.text)

                    if let sources = diagram.sources, !sources.isEmpty {
                        SourceList(sources: sources)
                    }
                }
                .padding()
            }
            .pettyScreen()
            .navigationTitle(diagram.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct SourceList: View {
    let sources: [SourceLink]
    @State private var browsing: URL?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCES")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(palette.accent)
            ForEach(sources, id: \.self) { source in
                Button { browsing = source.url } label: {
                    Label {
                        Text(source.title).multilineTextAlignment(.leading)
                    } icon: {
                        Image(systemName: "link")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.secondaryText)
            }
        }
        .inAppBrowser($browsing)
    }
}

struct DiagramGalleryView: View {
    @ObservedObject private var settings = StudySettings.shared
    private let library = ContentLibrary.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(library.diagrams(for: settings.exam)) { diagram in
                    Panel { DiagramCard(diagram: diagram) }
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Diagrams")
    }
}
