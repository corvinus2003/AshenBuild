import SwiftUI
import SwiftData

@main
struct AshenBuildApp: App {
    let modelContainer: ModelContainer
    let dataStore = DataStore.shared
    @AppStorage("appearance") private var appearance: AppAppearance = .dark

    init() {
        do {
            modelContainer = try ModelContainer(for: SavedBuild.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            BuildListView()
                .environment(dataStore)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(modelContainer)
    }
}
