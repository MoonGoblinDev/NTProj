// FILE: Novel Translator/Models/ViewModels/ChapterEditorState.swift
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
        
        // REMOVED: Do not modify self.translatedSelection here.
        // STTextView should manage its own cursor during text appends.
        // Programmatic selection will be handled by the caller (e.g., TranslationViewModel)
        // only at the start and end of major operations.
    }

    // MARK: - Search & Replace Methods

    /// Replaces a single occurrence of a search result.
    func replace(range: NSRange, with text: String, in editor: SearchResultItem.EditorType) {
        switch editor {
        case .source:
            var mutableText = self.sourceAttributedText
            if let swiftRange = Range(range, in: mutableText), !swiftRange.isEmpty {
                // Get attributes from the run at the location we are about to replace.
                let run = mutableText.runs[swiftRange.lowerBound]
                let attributes = run.attributes
                var replacement = AttributedString(text)
                replacement.setAttributes(attributes)

                mutableText.replaceSubrange(swiftRange, with: replacement)
                self.sourceAttributedText = mutableText
            }
        case .translated:
            var mutableText = self.translatedAttributedText
            if let swiftRange = Range(range, in: mutableText), !swiftRange.isEmpty {
                // Get attributes from the run at the location we are about to replace.
                // *** THIS IS THE FIX ***
                let run = mutableText.runs[swiftRange.lowerBound]
                let attributes = run.attributes
                var replacement = AttributedString(text)
                replacement.setAttributes(attributes)

                mutableText.replaceSubrange(swiftRange, with: replacement)
                self.translatedAttributedText = mutableText
            }
        }
    }

    /// Replaces all occurrences for a given editor type.
    func replaceAll(results: [SearchResultItem], with text: String, in editor: SearchResultItem.EditorType) {
        // Sort results in descending order of location to avoid invalidating subsequent ranges.
        let sortedResults = results.sorted { $0.absoluteMatchRange.location > $1.absoluteMatchRange.location }

        switch editor {
        case .source:
            // Work on a mutable copy
            var mutableText = self.sourceAttributedText
            for result in sortedResults {
                if let range = Range(result.absoluteMatchRange, in: mutableText), !range.isEmpty {
                    // Create replacement with proper attributes for each occurrence.
                    // *** THIS IS THE FIX ***
                    let run = mutableText.runs[range.lowerBound]
                    let attributes = run.attributes
                    var replacement = AttributedString(text)
                    replacement.setAttributes(attributes)
                    mutableText.replaceSubrange(range, with: replacement)
                }
            }
            // Assign the new struct back to the property to trigger a UI update.
            self.sourceAttributedText = mutableText
            
        case .translated:
            // Work on a mutable copy
            var mutableText = self.translatedAttributedText
            for result in sortedResults {
                if let range = Range(result.absoluteMatchRange, in: mutableText), !range.isEmpty {
                    // Create replacement with proper attributes for each occurrence.
                    // *** THIS IS THE FIX ***
                    let run = mutableText.runs[range.lowerBound]
                    let attributes = run.attributes
                    var replacement = AttributedString(text)
                    replacement.setAttributes(attributes)
                    mutableText.replaceSubrange(range, with: replacement)
                }
            }
            // Assign the new struct back to the property to trigger a UI update.
            self.translatedAttributedText = mutableText
        }
    }
}
