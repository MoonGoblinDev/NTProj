import SwiftUI
import Combine

@MainActor
class WorkspaceViewModel: ObservableObject {
    @Published var openChapterIDs: [UUID] = []
    @Published var activeChapterID: UUID?
    @Published var editorStates: [UUID: ChapterEditorState] = [:]

    // State for managing the "unsaved changes" alert
    @Published var chapterIDToClose: UUID?
    @Published var isCloseChapterAlertPresented: Bool = false
    
    // The source of truth for all project data. It's weak to avoid retain cycles.
    private(set) weak var project: TranslationProject?
    
    var activeChapter: Chapter? {
        guard let activeID = activeChapterID else { return nil }
        return fetchChapter(with: activeID)
    }

    var activeEditorState: ChapterEditorState? {
        guard let activeID = activeChapterID, let state = editorStates[activeID] else {
            return nil
        }
        return state
    }
    // A computed property that checks if any open chapter has unsaved changes.
    // This is the primary driver for enabling the "Save" menu item.
    var hasUnsavedEditorChanges: Bool {
        editorStates.values.contains { $0.hasUnsavedChanges }
    }
    
    func setCurrentProject(_ project: TranslationProject?) {
        self.project = project
        // When project changes, close everything.
        closeAllChapters()
    }

    func openChapter(id: UUID) {
        if !openChapterIDs.contains(id) {
            if let chapter = fetchChapter(with: id) {
                openChapterIDs.append(id)
                editorStates[id] = ChapterEditorState(chapter: chapter)
            }
        }
        activeChapterID = id
    }

    func closeChapter(id: UUID) {
        // If the chapter has unsaved changes, trigger the confirmation alert.
        if let state = editorStates[id], state.hasUnsavedChanges {
            self.chapterIDToClose = id
            self.isCloseChapterAlertPresented = true
        } else {
            // Otherwise, close it directly without an alert.
            forceCloseChapter(id: id)
        }
    }

    /// Saves the chapter and then closes it. Called from the alert.
    func saveAndCloseChapter() {
        guard let id = chapterIDToClose else { return }
        
        do {
            try updateChapterFromState(id: id)
            forceCloseChapter(id: id)
        } catch {
            print("Failed to save chapter before closing: \(error)")
            isCloseChapterAlertPresented = false
            chapterIDToClose = nil
        }
    }
    
    /// Discards changes and closes the chapter. Called from the alert.
    func discardAndCloseChapter() {
        guard let id = chapterIDToClose else { return }
        forceCloseChapter(id: id)
    }
    
    /// The core logic to close a chapter, now separated for re-use.
    private func forceCloseChapter(id: UUID) {
        editorStates.removeValue(forKey: id)
        openChapterIDs.removeAll { $0 == id }

        if activeChapterID == id {
            activeChapterID = openChapterIDs.last
        }
        
        isCloseChapterAlertPresented = false
        chapterIDToClose = nil
    }

    /// Updates the in-memory project model with the content from a specific editor state.
    func updateChapterFromState(id: UUID?) throws {
        guard let project = self.project else { return }
        guard let chapterID = id,
              let state = editorStates[chapterID],
              let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapterID }) else { return }

        if !state.hasUnsavedChanges {
            return
        }

        let rawContent = String(state.sourceAttributedText.characters)
        let translatedContent = String(state.translatedAttributedText.characters)
        
        let service = TranslationService()
        service.updateChapterWithManualChanges(
            project: project,
            chapterIndex: chapterIndex,
            rawContent: rawContent,
            translatedContent: translatedContent
        )

        if let refreshedChapter = fetchChapter(with: chapterID) {
            editorStates[chapterID] = ChapterEditorState(chapter: refreshedChapter)
        }
    }
    
    /// A central method called before saving the project file to commit all pending editor changes.
    func commitAllUnsavedChanges() throws {
        for id in editorStates.keys {
            try updateChapterFromState(id: id)
        }
    }
    
    func closeAllChapters() {
        openChapterIDs.removeAll()
        activeChapterID = nil
        editorStates.removeAll()
    }

    func fetchChapter(with id: UUID) -> Chapter? {
        return project?.chapters.first(where: { $0.id == id })
    }
}
