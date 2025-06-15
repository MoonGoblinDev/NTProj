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
                .environmentObject(workspaceViewModel) 
                .onChange(of: projectManager.currentProject) { _, newProject in
                    workspaceViewModel.setCurrentProject(newProject)
                }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "noveltranslator"))
        .commands {
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
            try workspaceViewModel.commitAllUnsavedChanges()
            projectManager.saveProject()
        } catch {
            print("Failed to save from menu command: \(error.localizedDescription)")
        }
    }
}
