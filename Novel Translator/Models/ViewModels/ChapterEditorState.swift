import SwiftUI

@Observable
class ChapterEditorState {
    let chapterID: UUID
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
        self.chapterID = chapter.id
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
