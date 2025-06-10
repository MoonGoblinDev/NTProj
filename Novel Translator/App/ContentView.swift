import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedProjectID: PersistentIdentifier?
    @State private var selectedChapterID: PersistentIdentifier?

    @Query(sort: \TranslationProject.lastModifiedDate, order: .reverse) private var projects: [TranslationProject]
    
    private var chapterToDisplay: Chapter? {
        guard let pID = selectedProjectID, let cID = selectedChapterID else { return nil }
        guard let project = projects.first(where: { $0.id == pID }) else { return nil }
        return project.chapters.first(where: { $0.id == cID })
    }

    var body: some View {
        // Use NavigationSplitView to get the hideable/resizable sidebar.
        NavigationSplitView {
            // --- The Sidebar ---
            // It only needs to know about the selected project and chapter.
            SidebarView(
                selectedProjectID: $selectedProjectID,
                selectedChapterID: $selectedChapterID,
                projects: projects // Pass projects to find the selected one
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

        } detail: {
            // --- The Main Content View ---
            // The workspace now needs access to all projects and the selected
            // project ID to render its new toolbar.
            TranslationWorkspaceView(
                chapter: chapterToDisplay,
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
