import SwiftUI

struct SimulatorLabView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Environment(\.bottomBarInset) private var bottomBarInset
    private let library = ContentLibrary.shared

    var body: some View {
        let tools = library.resources(for: settings.exam).filter { $0.id.hasPrefix("res-tool-") }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Built In")
                NavigationLink { LensometerTrainerView() } label: {
                    LinkRow(title: "Lensometer Trainer", subtitle: "Focus the target, find the axis, record sphere/cyl/axis", symbol: "scope")
                }
                .buttonStyle(.plain)
                NavigationLink { CalculatorsView() } label: {
                    LinkRow(title: "Calculators", subtitle: "Spectacle and contact lens formulas with explanations", symbol: "function")
                }
                .buttonStyle(.plain)
                if !tools.isEmpty {
                    SectionTitle(title: "Online Simulators & Tools", trailing: "\(tools.count)")
                    ForEach(tools) { ResourceRow(resource: $0) }
                }
            }
            .padding()
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle("Simulator Lab")
    }
}
