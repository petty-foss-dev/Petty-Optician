import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var theme = ThemeManager.shared
    @State private var tab = Tab.today

    enum Tab: Hashable { case today, binder, practice, cards, library }

    private var colors: ColorSet { theme.colors(for: colorScheme) }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openBinder: { tab = .binder })
                .tabItem { Label("Today", systemImage: "house") }
                .tag(Tab.today)
            StudyBinderView()
                .tabItem { Label("Binder", systemImage: "book.closed") }
                .tag(Tab.binder)
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
        // Widgets open pettyoptician://today or ://daily; Today holds the daily question.
        .onOpenURL { url in if url.scheme == "pettyoptician" { tab = .today } }
        // Pure black resolves into the palette, so rebuild the tabs when the theme changes.
        .id(theme.selectedTheme)
        .environment(\.palette, colors)
        .tint(colors.accent)
        .preferredColorScheme(theme.preferredColorScheme)
        // Matching questions to lessons takes a moment; do it off the main thread before the first explanation needs it.
        .task(priority: .utility) { await Task.detached { _ = LessonLinks.shared }.value }
    }
}
