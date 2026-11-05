import SwiftUI
import UIKit

struct BundledImage: View {
    let image: ImageInfo
    var maxPixel: CGFloat = 600
    var contentMode: ContentMode = .fill
    @State private var loaded: UIImage?
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            if let loaded {
                Image(uiImage: loaded).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(palette.secondaryText.opacity(0.1))
            }
        }
        .task(id: image.id) {
            guard let url = image.url, let full = UIImage(contentsOfFile: url.path()) else { return }
            let scale = min(1, maxPixel / max(full.size.width, full.size.height))
            loaded = await full.byPreparingThumbnail(ofSize: CGSize(width: full.size.width * scale, height: full.size.height * scale)) ?? full
        }
        .accessibilityLabel(image.title)
    }
}

struct ImageCard: View {
    let image: ImageInfo
    @State private var expanded = false
    @Environment(\.palette) private var palette

    var body: some View {
        Button { expanded = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .overlay { BundledImage(image: image) }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(image.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(image.credit)
                    .font(.caption2)
                    .foregroundStyle(palette.tertiaryText)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $expanded) { ImageDetailView(image: image) }
    }
}

struct ImageDetailView: View {
    let image: ImageInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BundledImage(image: image, maxPixel: 1600, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .scaleEffect(zoom * pinch)
                        .gesture(
                            MagnifyGesture()
                                .updating($pinch) { value, state, _ in state = value.magnification }
                                .onEnded { zoom = min(4, max(1, zoom * $0.magnification)) }
                        )
                        .onTapGesture(count: 2) { withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 2.5 } }
                        .zIndex(1)

                    Text(image.caption).font(.body).foregroundStyle(palette.text)
                    ImageCredit(image: image)
                }
                .padding()
            }
            .enveScreen()
            .navigationTitle(image.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct ImageCredit: View {
    let image: ImageInfo
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(image.credit).font(.caption).foregroundStyle(palette.secondaryText)
            HStack(spacing: 16) {
                BrowserLink(url: image.sourceURL) { Label("Source", systemImage: "link") }
                if let license = image.licenseURL {
                    BrowserLink(url: license) { Label(image.license, systemImage: "c.circle") }
                }
            }
            .font(.caption.weight(.semibold))
        }
    }
}

struct PhotoStrip: View {
    let images: [ImageInfo]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(images) { ImageCard(image: $0).frame(width: 200) }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct PhotoAtlasView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Environment(\.bottomBarInset) private var bottomBarInset
    private let library = ContentLibrary.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(library.domains(for: settings.exam)) { domain in
                    let images = library.images(for: settings.exam, domain: domain.id)
                    if !images.isEmpty {
                        SectionTitle(title: domain.name, trailing: "\(images.count)")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                            ForEach(images) { ImageCard(image: $0) }
                        }
                    }
                }
            }
            .padding()
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle("Photo Atlas")
    }
}

struct ImageCreditsView: View {
    private let images = ContentLibrary.shared.images

    var body: some View {
        List {
            Section {
                ForEach(images) { image in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(image.title).font(.subheadline.weight(.semibold))
                        ImageCredit(image: image)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("Photos come from Wikimedia Commons under the licenses shown and were resized for this app. Diagrams are original to Enve Optician.")
            }
        }
        .navigationTitle("Image Credits")
    }
}
