import SwiftUI
import SwiftData

struct ContentView: View {
    // Access the shared state object from the environment.
    @EnvironmentObject private var appContext: AppContext
    @Environment(WorkspaceViewModel.self) private var workspaceViewModel
    
    @State private var selectedProjectID: PersistentIdentifier?
    // REMOVED: @State private var selectedChapterID: PersistentIdentifier?

    @Query(sort: \TranslationProject.lastModifiedDate, order: .reverse) private var projects: [TranslationProject]
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedProjectID: $selectedProjectID,
                projects: projects
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

        } detail: {
            TranslationWorkspaceView(
                projects: projects,
                selectedProjectID: $selectedProjectID
            )
        }
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
        .onChange(of: selectedProjectID) {
            workspaceViewModel.closeAllChapters()
        }
        // The .onOpenURL now has a much simpler job.
        .onOpenURL { url in
            guard url.scheme == "noveltranslator", url.host == "glossary" else {
                return
            }
            
            // Just update the shared state. No notifications needed.
            if let uuid = UUID(uuidString: url.lastPathComponent) {
                appContext.glossaryEntryToEditID = uuid
            }
        }
    }
}
