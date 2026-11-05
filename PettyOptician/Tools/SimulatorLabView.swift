import SwiftUI

struct SimulatorLabView: View {
    @ObservedObject private var settings = StudySettings.shared
    private let library = ContentLibrary.shared

    var body: some View {
        let tools = library.resources(for: settings.exam).filter { $0.id.hasPrefix("res-tool-") }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Built In")
                ForEach(Trainer.allCases) { trainer in
                    NavigationLink { trainer.screen } label: {
                        LinkRow(title: trainer.title, subtitle: "\(trainer.exam.shortLabel) · \(trainer.subtitle)", symbol: trainer.symbol)
                    }
                    .buttonStyle(.plain)
                }
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
        .pettyScreen()
        .navigationTitle("Simulator Lab")
    }
}
