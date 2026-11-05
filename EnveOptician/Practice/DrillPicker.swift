import SwiftUI

struct DrillPicker: View {
    let exam: ExamID
    let start: ([Question]) -> Void
    @State private var kinds: Set<DrillGenerator.Kind> = []
    @State private var count = 10
    @Environment(\.palette) private var palette

    var body: some View {
        let available = DrillGenerator.kinds(for: exam)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Fresh numbers every time, with worked solutions. Pick the calculations to practice.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    FlowLayout(spacing: 8) {
                        Button { kinds = [] } label: { Chip(text: "All", selected: kinds.isEmpty) }
                        ForEach(available) { kind in
                            Button {
                                if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
                            } label: { Chip(text: kind.title, selected: kinds.contains(kind)) }
                        }
                    }
                    .buttonStyle(.plain)
                    Stepper("**\(count)** problems", value: $count, in: 5...50, step: 5)
                    Button {
                        var rng = SystemRandomNumberGenerator()
                        start(DrillGenerator.quiz(exam: exam, kinds: kinds.isEmpty ? available : Array(kinds), count: count, using: &rng))
                    } label: {
                        Text("Start Drills").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("drills.start")
                }
                .padding()
            }
            .navigationTitle("Math Drills")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
