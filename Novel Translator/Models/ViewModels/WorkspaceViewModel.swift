//
//  WorkspaceViewModel.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 12/06/25.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
class WorkspaceViewModel {
    var openChapterIDs: [PersistentIdentifier] = []
    var activeChapterID: PersistentIdentifier?
    var editorStates: [PersistentIdentifier: ChapterEditorState] = [:]

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
        // In a real app, you'd prompt to save if hasUnsavedChanges is true.
        // For now, we just discard the changes.
        if let state = editorStates[id], state.hasUnsavedChanges {
            print("Closing chapter '\(fetchChapter(with: id)?.title ?? "")' with unsaved changes. Discarding.")
        }

        editorStates.removeValue(forKey: id)
        openChapterIDs.removeAll { $0 == id }

        if activeChapterID == id {
            activeChapterID = openChapterIDs.last
        }
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
        openChapterIDs.removeAll()
        activeChapterID = nil
        editorStates.removeAll()
    }

    private func fetchChapter(with id: PersistentIdentifier) -> Chapter? {
        let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.persistentModelID == id })
        return try? self.modelContext.fetch(descriptor).first
    }
}
