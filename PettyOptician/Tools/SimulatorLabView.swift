import SwiftUI

struct SimulatorLabView: View {
    @ObservedObject private var settings = StudySettings.shared
    private let library = ContentLibrary.shared

    var body: some View {
        let tools = library.resources(for: settings.exam).filter { $0.id.hasPrefix("res-tool-") }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Free Online Simulators & Tools", trailing: "\(tools.count)")
                ForEach(tools) { ResourceRow(resource: $0) }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Online Simulators")
    }
}
