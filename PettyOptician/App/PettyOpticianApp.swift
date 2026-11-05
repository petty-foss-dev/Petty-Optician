import SwiftData
import SwiftUI

@main
struct PettyOpticianApp: App {
    private let modelContainer: ModelContainer

    init() {
        let inMemory = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        do {
            modelContainer = try ModelContainer(
                for: Schema(ProgressSchema.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("Unable to create progress store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
