import SwiftUI

/// A dedicated view for the side-by-side translation editor.
struct TranslationEditorView: View {
    let chapter: Chapter
    @Binding var translatedContent: String
    let matches: [GlossaryMatch]
    let isDisabled: Bool
    
    // A computed property to generate the Markdown string on-the-fly.
    private var sourceAsMarkdown: String {
        var markdownString = ""
        var currentIndex = chapter.rawContent.startIndex

        // Matches must be sorted by their start index.
        for match in matches {
            // Append non-matching text
            if match.range.lowerBound > currentIndex {
                markdownString += chapter.rawContent[currentIndex..<match.range.lowerBound]
            }
            
            // Append the glossary term as a Markdown link with our custom URL scheme.
            let matchedText = chapter.rawContent[match.range]
            let entryID = match.entry.id.uuidString
            // This creates the link, e.g., "[World](noveltranslator://glossary/SOME-UUID)"
            markdownString += "[\(matchedText)](noveltranslator://glossary/\(entryID))"
            
            currentIndex = match.range.upperBound
        }
        
        // Append any remaining text
        if currentIndex < chapter.rawContent.endIndex {
            markdownString += chapter.rawContent[currentIndex..<chapter.rawContent.endIndex]
        }
        
        return markdownString
    }

    var body: some View {
        HSplitView {
            // --- Left Panel: Source Text ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Source: \(chapter.project?.sourceLanguage ?? "")")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                // Pass the generated Markdown to our view.
                HighlightedTextView(markdownContent: sourceAsMarkdown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // --- Right Panel: Translated Text (unchanged) ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Translation: \(chapter.project?.targetLanguage ?? "") (\(chapter.translationStatus.rawValue))")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                TextEditor(text: $translatedContent)
                    .font(.system(.body, design: .serif))
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .disabled(isDisabled)
            }
        }
        .navigationTitle(chapter.title)
    }
}
