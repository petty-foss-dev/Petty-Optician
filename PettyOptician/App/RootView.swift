import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var theme = ThemeManager.shared
    @State private var tab = Tab.study

    enum Tab: Hashable { case today, study, practice, cards, library }

    private var colors: ColorSet { theme.colors(for: colorScheme) }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openStudy: { tab = .study })
                .tabItem { Label("Today", systemImage: "house") }
                .tag(Tab.today)
            TextbookView()
                .tabItem { Label("Study", systemImage: "book") }
                .tag(Tab.study)
            PracticeView()
                .tabItem { Label("Practice", systemImage: "checklist") }
                .tag(Tab.practice)
            FlashcardsView()
                .tabItem { Label("Cards", systemImage: "rectangle.on.rectangle.angled") }
                .tag(Tab.cards)
            LibraryView()
                .tabItem { Label("Library", systemImage: "play.rectangle.on.rectangle") }
                .tag(Tab.library)
        }
        .onOpenURL { url in if url.scheme == "pettyoptician" { tab = .today } }
        .id(theme.selectedTheme)
        .environment(\.palette, colors)
        .tint(colors.accent)
        .preferredColorScheme(theme.preferredColorScheme)
        .task(priority: .utility) { await Task.detached { _ = LessonLinks.shared }.value }
    }
}
