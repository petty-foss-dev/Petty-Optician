import SwiftUI

struct DynamicBackground: View {
    @State private var animate = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var theme = ThemeManager.shared

    private var colors: ColorSet { theme.colors(for: colorScheme) }

    var body: some View {
        ZStack {
            colors.background

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    Circle()
                        .fill(theme.themeColor.opacity(0.26))
                        .frame(width: w * 0.9)
                        .blur(radius: 60)
                        .offset(
                            x: animate ? w * 0.15 : w * 0.25,
                            y: animate ? -h * 0.05 : -h * 0.12
                        )
                        .animation(.easeInOut(duration: 28).repeatForever(autoreverses: true), value: animate)

                    Circle()
                        .fill(colors.accent.opacity(0.16))
                        .frame(width: w * 0.85)
                        .blur(radius: 60)
                        .offset(
                            x: animate ? -w * 0.08 : -w * 0.18,
                            y: animate ? h * 0.1 : h * 0.18
                        )
                        .animation(.easeInOut(duration: 34).repeatForever(autoreverses: true), value: animate)
                }
                .frame(width: w, height: h)
                .clipped()
                .drawingGroup()
            }
        }
        .onAppear { animate = scenePhase == .active }
        .onChange(of: scenePhase) { _, newPhase in
            animate = newPhase == .active
        }
    }
}

private struct EnveScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background { DynamicBackground().ignoresSafeArea() }
            .scrollContentBackground(.hidden)
    }
}

extension View {
    func enveScreen() -> some View {
        modifier(EnveScreenModifier())
    }
}
