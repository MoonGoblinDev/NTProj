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
        .commands {
            // Replaces the standard "Save" item in the File menu
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveActiveChapter()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!canSave())
            }
        }
    }
    
    // MARK: - Menu Command Helpers
    
    /// Checks if the active chapter has unsaved changes.
    private func canSave() -> Bool {
        guard let activeID = workspaceViewModel.activeChapterID else {
            return false
        }
        // The save option is enabled only if there's an active chapter
        // and its editor state shows unsaved changes.
        return workspaceViewModel.editorStates[activeID]?.hasUnsavedChanges ?? false
    }
    
    /// Triggers the save action on the workspace view model.
    private func saveActiveChapter() {
        do {
            try workspaceViewModel.saveChapter(id: workspaceViewModel.activeChapterID)
        } catch {
            // Error handling from a menu item is limited. We'll log it to the console.
            print("Failed to save from menu command: \(error.localizedDescription)")
        }
    }
}
