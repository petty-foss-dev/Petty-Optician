import SafariServices
import SwiftUI
import WebKit

extension StudyResource {
    var youTubePlaylistID: String? {
        guard [.playlist, .video].contains(kind), let host = url.host(), host.contains("youtube.com") else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "list" }?.value
    }

    /// Embed URL for videos and playlists that can play inside the app.
    var embedURL: URL? {
        var components = URLComponents(string: "https://www.youtube-nocookie.com")!
        if let id = youTubeID {
            components.path = "/embed/\(id)"
        } else if let list = youTubePlaylistID {
            components.path = "/embed/videoseries"
            components.queryItems = [URLQueryItem(name: "list", value: list)]
        } else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "rel", value: "0")
        ]
        return components.url
    }
}

struct YouTubeEmbed: UIViewRepresentable {
    let embedURL: URL

    /// YouTube refuses embeds without a referrer (error 153), so the page gets an https origin.
    private static let origin = URL(string: "https://app.pettyoptician.local")!

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.loadHTMLString(html, baseURL: Self.origin)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    private var html: String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="\(embedURL.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
          allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>
        </body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            action.navigationType == .linkActivated && action.targetFrame?.isMainFrame != false ? .cancel : .allow
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }
    }
}

struct VideoPlayerView: View {
    let resource: StudyResource
    let embedURL: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var browsing: URL?
    private let library = ContentLibrary.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    YouTubeEmbed(embedURL: embedURL)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityIdentifier("video.player")

                    Text(resource.title).font(.title3.weight(.bold)).foregroundStyle(palette.text)
                    HStack(spacing: 8) {
                        if let author = resource.author { Label(author, systemImage: "person.crop.circle") }
                        if let minutes = resource.minutes { Label("\(minutes) min", systemImage: "clock") }
                    }
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)

                    if let description = resource.description {
                        Text(description).font(.body).foregroundStyle(palette.text)
                    }
                    if let domains = resource.domains, !domains.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(domains, id: \.self) { Chip(text: library.domainName($0)) }
                        }
                    }
                    Button { browsing = resource.url } label: {
                        Label("Open on YouTube", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                    }
                }
                .padding()
            }
            .pettyScreen()
            .navigationTitle(resource.kind == .playlist ? "Playlist" : "Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .inAppBrowser($browsing)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = ThemeManager.accentUIColor
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct BrowserTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

extension View {
    /// Presents http(s) links in an in-app Safari sheet; other schemes go to the system.
    func inAppBrowser(_ url: Binding<URL?>) -> some View {
        modifier(InAppBrowserModifier(url: url))
    }
}

private struct InAppBrowserModifier: ViewModifier {
    @Binding var url: URL?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: Binding(
                get: { url.flatMap { ["http", "https"].contains($0.scheme) ? BrowserTarget(url: $0) : nil } },
                set: { if $0 == nil { url = nil } }
            )) { target in
                SafariView(url: target.url).ignoresSafeArea()
            }
            .onChange(of: url) { _, newValue in
                if let newValue, !["http", "https"].contains(newValue.scheme) {
                    openURL(newValue)
                    url = nil
                }
            }
    }
}

struct BrowserLink<Content: View>: View {
    let url: URL
    @ViewBuilder var label: Content
    @State private var browsing: URL?

    var body: some View {
        Button { browsing = url } label: { label }
            .inAppBrowser($browsing)
    }
}
