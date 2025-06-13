import SwiftUI
import SwiftData

@main
struct NovelTranslatorApp: App {
    @StateObject private var appContext = AppContext()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TranslationProject.self,
            Chapter.self,
            GlossaryEntry.self,
            TranslationVersion.self,
            APIConfiguration.self,
            TranslationStats.self,
            ImportSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        Window("Novel Translator", id: "main") {
            ContentView()
                .environmentObject(appContext)
        }
        .modelContainer(sharedModelContainer)
        .handlesExternalEvents(matching: Set(arrayLiteral: "noveltranslator"))
    }
}
