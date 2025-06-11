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
        // THE FIX: Replace WindowGroup with Window.
        // Window declares a scene for a single, unique window,
        // which is exactly what our application is. This is the key.
        Window("Novel Translator", id: "main") {
            ContentView()
                .environmentObject(appContext)
        }
        .modelContainer(sharedModelContainer)
        // .handlesExternalEvents is no longer strictly necessary because
        // a `Window` scene inherently handles events by routing to the
        // single existing window, but it is good practice to keep it
        // for clarity and future compatibility.
        .handlesExternalEvents(matching: Set(arrayLiteral: "noveltranslator"))
    }
}
