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
        let container = AttributeContainer([.foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 14)])

        self.sourceAttributedText = AttributedString(chapter.rawContent, attributes: container)
        self.translatedAttributedText = AttributedString(chapter.translatedContent ?? "", attributes: container)
    }
    
    func updateTranslation(newText: String) {
        // Retain basic attributes when updating
        let container = AttributeContainer([.foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 14)])
        self.translatedAttributedText = AttributedString(newText, attributes: container)
        
        if let currentSelection = self.translatedSelection {
            let newLength = newText.utf16.count // Use utf16.count for NSRange compatibility
            if (currentSelection.location + currentSelection.length) > newLength {
                self.translatedSelection = NSRange(location: newLength, length: 0)
            }
        }
    }

    // MARK: - Search & Replace Methods

    /// Replaces a single occurrence of a search result.
    func replace(range: NSRange, with text: String, in editor: SearchResultItem.EditorType) {
        let replacement = AttributedString(text)
        switch editor {
        case .source:
            // Create a mutable copy
            var mutableText = self.sourceAttributedText
            if let swiftRange = Range(range, in: mutableText) {
                mutableText.replaceSubrange(swiftRange, with: replacement)
                // Assign the new struct back to the property to force an update.
                self.sourceAttributedText = mutableText
            }
        case .translated:
            // Create a mutable copy
            var mutableText = self.translatedAttributedText
            if let swiftRange = Range(range, in: mutableText) {
                mutableText.replaceSubrange(swiftRange, with: replacement)
                // Assign the new struct back to the property to force an update.
                self.translatedAttributedText = mutableText
            }
        }
    }

    /// Replaces all occurrences for a given editor type.
    func replaceAll(results: [SearchResultItem], with text: String, in editor: SearchResultItem.EditorType) {
        // Sort results in descending order of location to avoid invalidating subsequent ranges.
        let sortedResults = results.sorted { $0.absoluteMatchRange.location > $1.absoluteMatchRange.location }
        let replacement = AttributedString(text)

        switch editor {
        case .source:
            // Work on a mutable copy
            var mutableText = self.sourceAttributedText
            for result in sortedResults {
                if let range = Range(result.absoluteMatchRange, in: mutableText) {
                    mutableText.replaceSubrange(range, with: replacement)
                }
            }
            // Assign the new struct back to the property to trigger a UI update.
            self.sourceAttributedText = mutableText
            
        case .translated:
            // Work on a mutable copy
            var mutableText = self.translatedAttributedText
            for result in sortedResults {
                if let range = Range(result.absoluteMatchRange, in: mutableText) {
                    mutableText.replaceSubrange(range, with: replacement)
                }
            }
            // Assign the new struct back to the property to trigger a UI update.
            self.translatedAttributedText = mutableText
        }
    }
}
