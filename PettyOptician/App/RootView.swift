import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var theme = ThemeManager.shared

    private var colors: ColorSet { theme.colors(for: colorScheme) }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "house") }
            StudyView()
                .tabItem { Label("Study", systemImage: "book") }
            PracticeView()
                .tabItem { Label("Practice", systemImage: "checklist") }
            FlashcardsView()
                .tabItem { Label("Cards", systemImage: "rectangle.on.rectangle.angled") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "play.rectangle.on.rectangle") }
        }
        // Pure black resolves into the palette, so rebuild the tabs when the theme changes.
        .id(theme.selectedTheme)
        .environment(\.palette, colors)
        .tint(colors.accent)
        .preferredColorScheme(theme.preferredColorScheme)
    }
}
