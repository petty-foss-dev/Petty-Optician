import Combine
import SwiftUI

struct ColorSet {
    let background: Color
    let secondaryBackground: Color
    let cardBackground: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let separator: Color

    static func oled(accent: Color) -> ColorSet {
        ColorSet(
            background: .black,
            secondaryBackground: Color(white: 0.05),
            cardBackground: Color(white: 0.1),
            text: .white,
            secondaryText: Color(white: 0.7),
            tertiaryText: Color(white: 0.5),
            accent: accent,
            separator: Color(white: 0.2)
        )
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    nonisolated static let defaultThemeHex = "#F5921A"

    nonisolated static var defaultAccentColor: Color {
        Color(red: 245.0 / 255.0, green: 146.0 / 255.0, blue: 26.0 / 255.0)
    }

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case oled = "OLED"
        var id: String { rawValue }
    }

    private static let selectedThemeKey = "enveoptician.selectedAppTheme"
    private static let themeColorHexKey = "enveoptician.themeColorHex"

    @Published var selectedTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.selectedThemeKey) }
    }

    @Published private var themeColorHex: String {
        didSet { UserDefaults.standard.set(themeColorHex, forKey: Self.themeColorHexKey) }
    }

    private init() {
        selectedTheme = UserDefaults.standard.string(forKey: Self.selectedThemeKey)
            .flatMap(AppTheme.init(rawValue:)) ?? .system
        themeColorHex = UserDefaults.standard.string(forKey: Self.themeColorHexKey) ?? Self.defaultThemeHex
    }

    var themeColor: Color {
        Color(hex: themeColorHex) ?? Self.defaultAccentColor
    }

    var currentThemeHex: String { themeColorHex }

    func updateThemeColorHex(_ hex: String) {
        guard themeColorHex != hex else { return }
        themeColorHex = hex
    }

    var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: nil
        case .light: .light
        case .dark, .oled: .dark
        }
    }

    private var isOLEDDevice: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen.traitCollection.displayGamut == .P3
    }

    func colors(for systemScheme: ColorScheme) -> ColorSet {
        let accent = themeColor

        let effectiveScheme: ColorScheme
        let useOLED: Bool
        switch selectedTheme {
        case .system:
            effectiveScheme = systemScheme
            useOLED = isOLEDDevice && systemScheme == .dark
        case .light:
            effectiveScheme = .light
            useOLED = false
        case .dark:
            effectiveScheme = .dark
            useOLED = false
        case .oled:
            effectiveScheme = .dark
            useOLED = true
        }

        if useOLED {
            return .oled(accent: accent)
        }

        return ColorSet(
            background: Color(.systemBackground),
            secondaryBackground: Color(.secondarySystemBackground),
            cardBackground: effectiveScheme == .light
                ? Color(.systemBackground)
                : Color(.secondarySystemBackground),
            text: Color(.label),
            secondaryText: Color(.secondaryLabel),
            tertiaryText: Color(.tertiaryLabel),
            accent: accent,
            separator: Color(.separator)
        )
    }
}

extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255
        )
    }
}
