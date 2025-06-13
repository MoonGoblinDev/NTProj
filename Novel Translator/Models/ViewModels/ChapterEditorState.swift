//
//  ChapterEditorState.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 12/06/25.
//

import SwiftUI
import SwiftData

@Observable
class ChapterEditorState {
    let chapterID: PersistentIdentifier
    private let initialRawContent: String
    private let initialTranslatedContent: String

    var sourceAttributedText: AttributedString
    var translatedAttributedText: AttributedString
    
    var sourceSelection: NSRange?
    var translatedSelection: NSRange?
    
    var hasUnsavedChanges: Bool {
        let currentRaw = String(sourceAttributedText.characters)
        let currentTranslated = String(translatedAttributedText.characters)
        
        return currentRaw != initialRawContent || currentTranslated != initialTranslatedContent
    }

    init(chapter: Chapter) {
        self.chapterID = chapter.persistentModelID
        self.initialRawContent = chapter.rawContent
        self.initialTranslatedContent = chapter.translatedContent ?? ""

        // Basic attributes
        var container = AttributeContainer()
        container.font = NSFont.systemFont(ofSize: 14)
        container.foregroundColor = NSColor.textColor

        self.sourceAttributedText = AttributedString(chapter.rawContent, attributes: container)
        self.translatedAttributedText = AttributedString(chapter.translatedContent ?? "", attributes: container)
    }
    
    func updateTranslation(newText: String) {
        // Retain basic attributes when updating
        var container = AttributeContainer()
        container.font = NSFont.systemFont(ofSize: 14)
        container.foregroundColor = NSColor.textColor
        self.translatedAttributedText = AttributedString(newText, attributes: container)
    }
}
