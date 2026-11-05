import SwiftUI

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = ColorSet.light
}

extension EnvironmentValues {
    var palette: ColorSet {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    @Environment(\.palette) private var palette

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(palette.separator, lineWidth: 0.5)
                    }
            }
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct Chip: View {
    let text: String
    var symbol: String?
    var selected = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(selected ? palette.onAccent : palette.secondaryText)
        .background(
            Capsule().fill(selected ? palette.accent : palette.secondaryText.opacity(0.12))
        )
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle().stroke(palette.accent.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
    }
}

struct MeterBar: View {
    let value: Double
    var tint: Color?
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.secondaryText.opacity(0.15))
                Capsule()
                    .fill(tint ?? palette.accent)
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 6)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    @Environment(\.palette) private var palette

    var body: some View {
        Panel(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.text)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }
}

/// Renders guide bodies: blank-line paragraphs, "- " bullets, inline markdown.
struct RichText: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let line):
                    Text(Self.markdown(line))
                        .fixedSize(horizontal: false, vertical: true)
                case .bullets(let items):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(palette.accent).frame(width: 5, height: 5)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 1 }
                                Text(Self.markdown(item))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Block {
        case paragraph(String)
        case bullets([String])
    }

    private var blocks: [Block] {
        text.components(separatedBy: "\n\n").flatMap { chunk -> [Block] in
            var result: [Block] = []
            var bullets: [String] = []
            var prose: [String] = []
            func flushProse() {
                if !prose.isEmpty { result.append(.paragraph(prose.joined(separator: " "))) }
                prose = []
            }
            func flushBullets() {
                if !bullets.isEmpty { result.append(.bullets(bullets)) }
                bullets = []
            }
            for raw in chunk.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("- ") || line.hasPrefix("• ") {
                    flushProse()
                    bullets.append(String(line.dropFirst(2)))
                } else if !line.isEmpty {
                    flushBullets()
                    prose.append(line)
                }
            }
            flushProse()
            flushBullets()
            return result
        }
    }

    static func markdown(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }
}

struct ExamSwitcher: View {
    @ObservedObject private var settings = StudySettings.shared
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExamID.allCases) { exam in
                let active = settings.exam == exam
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { settings.exam = exam }
                } label: {
                    Text(exam.shortLabel)
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .foregroundStyle(active ? palette.onAccent : palette.secondaryText)
                        .background(Capsule().fill(active ? palette.accent : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exam.\(exam.rawValue)")
            }
        }
        .padding(3)
        .background(Capsule().fill(palette.cardBackground))
        .overlay(Capsule().strokeBorder(palette.separator, lineWidth: 0.5))
    }
}

extension View {
    func tabScreen(_ title: String) -> some View {
        modifier(TabScreenModifier(title: title))
    }
}

private struct TabScreenModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .pettyScreen()
            .navigationTitle(title)
    }
}

extension Int {
    var durationLabel: String {
        let h = self / 3600, m = (self % 3600) / 60, s = self % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
