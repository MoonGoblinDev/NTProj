import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedProjectID: PersistentIdentifier?
    @State private var selectedChapterID: PersistentIdentifier?

    @Query(sort: \TranslationProject.lastModifiedDate, order: .reverse) private var projects: [TranslationProject]
    

    var body: some View {
        NavigationSplitView {
            // --- The Sidebar ---
            SidebarView(
                selectedProjectID: $selectedProjectID,
                selectedChapterID: $selectedChapterID,
                projects: projects
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

        } detail: {
            // --- The Main Content View ---
            // The workspace now takes bindings to the selected IDs.
            // It will fetch the chapter object itself using a query.
            TranslationWorkspaceView(
                selectedChapterID: $selectedChapterID,
                projects: projects,
                selectedProjectID: $selectedProjectID
            )
        }
        .onAppear {
            // On first launch, select the most recent project
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
        .onChange(of: selectedProjectID) {
            // When the project changes, clear the chapter selection
            selectedChapterID = nil
        }
    }
}
