import SwiftUI

@main
struct NovelTranslatorApp: App {
    @StateObject private var appContext = AppContext()
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()

    var body: some Scene {
        Window("Novel Translator", id: "main") {
            ContentView()
                .environmentObject(appContext)
                .environmentObject(projectManager)
                .environmentObject(workspaceViewModel) // FIX: Use environmentObject for ObservableObject
                .onChange(of: projectManager.currentProject) { _, newProject in // FIX: Equatable conformance on TranslationProject handles this
                    // When the project manager loads a new project, tell the workspace about it.
                    workspaceViewModel.setCurrentProject(newProject)
                }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "noveltranslator"))
        .commands {
            // Replaces the standard "Save" item in the File menu
            CommandGroup(replacing: .saveItem) {
                Button("Save Project") {
                    saveProject()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!canSave())
            }
            
            CommandGroup(after: .newItem) {
                Button("Open Project...") {
                    projectManager.openProject()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Close Project") {
                    // TODO: Add an unsaved changes check here
                    projectManager.closeProject()
                }
                .disabled(projectManager.currentProject == nil)
            }
        }
    }
    
    // MARK: - Menu Command Helpers
    
    /// The save option is enabled if the workspace has any unsaved editor changes.
    private func canSave() -> Bool {
        workspaceViewModel.hasUnsavedEditorChanges
    }
    
    /// Triggers the save action on the workspace view model.
    private func saveProject() {
        do {
            // First, ensure any unsaved text in editors is written to the project model
            try workspaceViewModel.commitAllUnsavedChanges()
            // Then, tell the project manager to write the project file to disk
            projectManager.saveProject()
        } catch {
            // Error handling from a menu item is limited. We'll log it to the console.
            print("Failed to save from menu command: \(error.localizedDescription)")
        }
    }
}
