import SwiftUI
import SwiftData

@MainActor
@Observable
class WorkspaceViewModel {
    var openChapterIDs: [PersistentIdentifier] = []
    var activeChapterID: PersistentIdentifier?
    var editorStates: [PersistentIdentifier: ChapterEditorState] = [:]

    // State for managing the "unsaved changes" alert
    var chapterIDToClose: PersistentIdentifier?
    var isCloseChapterAlertPresented: Bool = false
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func openChapter(id: PersistentIdentifier) {
        if !openChapterIDs.contains(id) {
            if let chapter = fetchChapter(with: id) {
                openChapterIDs.append(id)
                editorStates[id] = ChapterEditorState(chapter: chapter)
            }
        }
        activeChapterID = id
    }

    func closeChapter(id: PersistentIdentifier) {
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
        
        Task {
            do {
                try saveChapter(id: id)
                // If save is successful, proceed with closing.
                forceCloseChapter(id: id)
            } catch {
                print("Failed to save chapter before closing: \(error)")
                // In case of error, just dismiss the alert and leave the chapter open.
                isCloseChapterAlertPresented = false
                chapterIDToClose = nil
            }
        }
    }
    
    /// Discards changes and closes the chapter. Called from the alert.
    func discardAndCloseChapter() {
        guard let id = chapterIDToClose else { return }
        forceCloseChapter(id: id)
    }
    
    /// The core logic to close a chapter, now separated for re-use.
    private func forceCloseChapter(id: PersistentIdentifier) {
        editorStates.removeValue(forKey: id)
        openChapterIDs.removeAll { $0 == id }

        if activeChapterID == id {
            activeChapterID = openChapterIDs.last
        }
        
        // Reset alert state
        isCloseChapterAlertPresented = false
        chapterIDToClose = nil
    }

    func saveChapter(id: PersistentIdentifier?) throws {
        guard let chapterID = id,
              let state = editorStates[chapterID],
              let chapter = fetchChapter(with: chapterID) else { return }

        if !state.hasUnsavedChanges {
            return
        }

        let rawContent = String(state.sourceAttributedText.characters)
        let translatedContent = String(state.translatedAttributedText.characters)
        
        let service = TranslationService(modelContext: modelContext)
        try service.saveManualChanges(
            for: chapter,
            rawContent: rawContent,
            translatedContent: translatedContent
        )

        // After saving, the baseline for "unsaved" has changed.
        // We replace the state object with a new one to reset the `hasUnsavedChanges` flag.
        if let refreshedChapter = fetchChapter(with: chapterID) {
            editorStates[chapterID] = ChapterEditorState(chapter: refreshedChapter)
        }
    }
    
    func closeAllChapters() {
        // A simple implementation that discards all changes.
        // A more robust app would check for any unsaved changes here.
        openChapterIDs.removeAll()
        activeChapterID = nil
        editorStates.removeAll()
    }

    /// **FIXED:** Fetches a chapter directly from the model context using its persistent ID.
    /// This method is now accessible by the View layer for displaying alert messages.
    func fetchChapter(with id: PersistentIdentifier) -> Chapter? {
        let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.persistentModelID == id })
        return try? self.modelContext.fetch(descriptor).first
    }
}
