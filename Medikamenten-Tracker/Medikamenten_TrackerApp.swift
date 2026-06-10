import SwiftUI
import SwiftData

@main
struct Medikamenten_TrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Medication.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema hat sich geändert: alte Datenbank löschen und neu erstellen
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupportDir = urls.first {
                let storeFiles = ["default.store", "default.store-shm", "default.store-wal"]
                for file in storeFiles {
                    let url = appSupportDir.appendingPathComponent(file)
                    try? FileManager.default.removeItem(at: url)
                }
            }

            // Erneut versuchen mit sauberer Datenbank
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
