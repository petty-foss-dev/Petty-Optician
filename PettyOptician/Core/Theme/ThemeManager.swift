import Combine
import SwiftUI

/// The Petty palette shared with petty: Tracker and petty: Jobs: cool grays around a blue-green accent.
struct ColorSet {
    let background: Color
    let cardBackground: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let onAccent: Color
    let separator: Color

    static let light = ColorSet(
        background: Color(hex: 0xF3F5F6),
        cardBackground: .white,
        text: Color(hex: 0x1B2328),
        secondaryText: Color(.secondaryLabel),
        tertiaryText: Color(.tertiaryLabel),
        accent: Color(hex: 0x0F7A8A),
        onAccent: .white,
        separator: .black.opacity(0.08)
    )

    static func dark(pureBlack: Bool) -> ColorSet {
        ColorSet(
            background: pureBlack ? .black : Color(hex: 0x0E1113),
            cardBackground: Color(hex: pureBlack ? 0x0B0D0E : 0x181D20),
            text: Color(hex: 0xE6EBEE),
            secondaryText: Color(.secondaryLabel),
            tertiaryText: Color(.tertiaryLabel),
            accent: Color(hex: 0x4FC1C9),
            onAccent: Color(hex: 0x0B1F22),
            separator: .white.opacity(0.09)
        )
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    static let accentUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x4F / 255, green: 0xC1 / 255, blue: 0xC9 / 255, alpha: 1)
            : UIColor(red: 0x0F / 255, green: 0x7A / 255, blue: 0x8A / 255, alpha: 1)
    }

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case pureBlack = "Pure Black"
        var id: String { rawValue }
    }

    private static let selectedThemeKey = "pettyoptician.selectedAppTheme"

    @Published var selectedTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.selectedThemeKey) }
    }

    private init() {
        selectedTheme = UserDefaults.standard.string(forKey: Self.selectedThemeKey)
            .flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: nil
        case .light: .light
        case .dark, .pureBlack: .dark
        }
    }

    func colors(for systemScheme: ColorScheme) -> ColorSet {
        switch selectedTheme {
        case .system: systemScheme == .dark ? .dark(pureBlack: false) : .light
        case .light: .light
        case .dark: .dark(pureBlack: false)
        case .pureBlack: .dark(pureBlack: true)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct PettyScreenModifier: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .background { palette.background.ignoresSafeArea() }
            .scrollContentBackground(.hidden)
    }
}

extension View {
    func pettyScreen() -> some View {
        modifier(PettyScreenModifier())
    }
}
