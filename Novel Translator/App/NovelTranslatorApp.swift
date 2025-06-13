import SwiftUI
import SwiftData

@main
struct NovelTranslatorApp: App {
    @StateObject private var appContext = AppContext()
    @State private var workspaceViewModel: WorkspaceViewModel

    let sharedModelContainer: ModelContainer
    
    init() {
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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            self._workspaceViewModel = State(initialValue: WorkspaceViewModel(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        Window("Novel Translator", id: "main") {
            ContentView()
                .environmentObject(appContext)
                .environment(workspaceViewModel)
        }
        .modelContainer(sharedModelContainer)
        .handlesExternalEvents(matching: Set(arrayLiteral: "noveltranslator"))
    }
}
