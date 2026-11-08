import Combine
import CoreData
import SwiftData
import SwiftUI

@main
struct PettyOpticianApp: App {
    static let cloudContainer = "iCloud.com.isaaclamb.PettyOptician"

    private let modelContainer: ModelContainer
    private let tipUpdates = Tip.finishLateTransactions()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Unit tests run inside the app; they must never touch the real store or iCloud.
        let inMemory = ProcessInfo.processInfo.arguments.contains("--ui-testing") || NSClassFromString("XCTestCase") != nil
        do {
            modelContainer = try ModelContainer(
                for: Schema(ProgressSchema.models),
                // Pinned to the app's container: with an App Group, SwiftData would open a new, empty store there.
                configurations: inMemory
                    ? ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                    : ModelConfiguration(url: .applicationSupportDirectory.appending(path: "default.store"), cloudKitDatabase: .private(Self.cloudContainer))
            )
        } catch {
            fatalError("Unable to create progress store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
                    ProgressMerge.run(in: modelContainer.mainContext)
                    WidgetPublisher.publish(in: modelContainer.mainContext)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: ModelContext.didSave).map { _ in }
                        .merge(with: StudySettings.shared.objectWillChange.map { _ in })
                        .debounce(for: .seconds(1), scheduler: RunLoop.main)
                ) { _ in
                    WidgetPublisher.publish(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: ProgressMerge.run(in: modelContainer.mainContext)
            case .background: WidgetPublisher.publish(in: modelContainer.mainContext)
            default: break
            }
        }
    }
}
