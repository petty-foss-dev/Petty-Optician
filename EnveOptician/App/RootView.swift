import SwiftUI

struct RootView: View {
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var theme = ThemeManager.shared

    private var colors: ColorSet { theme.colors(for: colorScheme) }
    private let tabBarHeight: CGFloat = 56

    private static let tabs: [Tab] = [
        Tab(tag: 0, icon: "house", filled: "house.fill", label: "Today"),
        Tab(tag: 1, icon: "book", filled: "book.fill", label: "Study"),
        Tab(tag: 2, icon: "checklist", filled: "checklist", label: "Practice"),
        Tab(tag: 3, icon: "rectangle.on.rectangle.angled", filled: "rectangle.on.rectangle.angled.fill", label: "Cards"),
        Tab(tag: 4, icon: "play.rectangle.on.rectangle", filled: "play.rectangle.on.rectangle.fill", label: "Library")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                content
                    .environment(\.bottomBarInset, tabBarHeight + 16 + geo.safeAreaInsets.bottom)
                    .environment(\.palette, colors)
                    .zIndex(0)

                tabBar
                    .zIndex(1)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.palette, colors)
        .tint(colors.accent)
        .preferredColorScheme(theme.preferredColorScheme)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case 0: HomeView()
        case 1: StudyView()
        case 2: PracticeView()
        case 3: FlashcardsView()
        default: LibraryView()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs) { tab in
                let active = selectedTab == tab.tag
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab.tag
                    }
                } label: {
                    ZStack {
                        if active {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(colors.accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
                        }

                        HStack(spacing: 5) {
                            Image(systemName: active ? tab.filled : tab.icon)
                                .font(.system(size: 18, weight: active ? .semibold : .medium))
                            if active {
                                Text(tab.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .foregroundStyle(active ? colors.accent : colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.label.lowercased())")
            }
        }
        .padding(6)
        .frame(maxWidth: min(420, CGFloat(Self.tabs.count) * 76 + 24))
        .frame(height: tabBarHeight)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 20, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private struct Tab: Identifiable {
        let tag: Int
        let icon: String
        let filled: String
        let label: String
        var id: Int { tag }
    }
}
