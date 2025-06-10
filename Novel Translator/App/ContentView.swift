import SwiftUI
import SwiftData

struct ContentView: View {
    // State management for the SELECTION IDs
    @State private var selectedProjectID: PersistentIdentifier?
    @State private var selectedChapterID: PersistentIdentifier?

    // Query to get all projects
    @Query(sort: \TranslationProject.lastModifiedDate, order: .reverse) private var projects: [TranslationProject]
    
    // --- NEW IMPLEMENTATION ---
    // A computed property that FINDS the actual Chapter object based on the selected IDs.
    // This is where the logic now lives.
    private var chapterToDisplay: Chapter? {
        // Ensure we have a project ID and a chapter ID
        guard let pID = selectedProjectID, let cID = selectedChapterID else { return nil }
        
        // Find the project that matches the project ID
        guard let project = projects.first(where: { $0.id == pID }) else { return nil }
        
        // Find the chapter within that project that matches the chapter ID
        return project.chapters.first(where: { $0.id == cID })
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                projects: projects,
                selectedProjectID: $selectedProjectID,
                selectedChapterID: $selectedChapterID
            )
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 500)
            
            Divider()

            // Pass the complete, optional Chapter object directly.
            // We no longer need the .id() modifier.
            TranslationWorkspaceView(chapter: chapterToDisplay)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedProjectID) {
            // When the project changes, clear the chapter selection
            selectedChapterID = nil
        }
        .onAppear {
            // On first launch, select the most recent project
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
    }
}
