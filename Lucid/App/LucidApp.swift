import SwiftUI
import SwiftData

@main
struct LucidApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Song.self, Playlist.self, RadioStation.self, RadioCountry.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(modelContainer)
                .environmentObject(PlayerViewModel())
                .onAppear {
                    Task {
                        await RadioBrowserService(modelContext: modelContainer.mainContext)
                            .refreshCountriesIfStale()
                    }
                }
        }
    }
}
