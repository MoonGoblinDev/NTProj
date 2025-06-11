import SwiftUI
import SwiftData

struct ContentView: View {
    // Access the shared state object from the environment.
    @EnvironmentObject private var appContext: AppContext
    
    @State private var selectedProjectID: PersistentIdentifier?
    @State private var selectedChapterID: PersistentIdentifier?

    @Query(sort: \TranslationProject.lastModifiedDate, order: .reverse) private var projects: [TranslationProject]
    
    var body: some View {
        NavigationSplitView {
            // ... (SidebarView is unchanged)
            SidebarView(
                selectedProjectID: $selectedProjectID,
                selectedChapterID: $selectedChapterID,
                projects: projects
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

        } detail: {
            // ... (TranslationWorkspaceView is unchanged here)
            TranslationWorkspaceView(
                selectedChapterID: $selectedChapterID,
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
            selectedChapterID = nil
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
