import SwiftUI

/// A dedicated view for the side-by-side translation editor.
struct TranslationEditorView: View {
    let chapter: Chapter
    @Binding var translatedContent: String
    let matches: [GlossaryMatch]
    let isDisabled: Bool
    
    // This computed property is now much more robust.
    private var textLines: [[TextComponent]] {
        // Create a flat map of all characters in the text, associating them
        // with any glossary entry they belong to.
        var characterMap: [(char: Character, entry: GlossaryEntry?)] = chapter.rawContent.map { ($0, nil) }
        
        for match in matches {
            // The range from the matcher is for the entire string, which is what we want.
            let rangeStartIndex = chapter.rawContent.distance(from: chapter.rawContent.startIndex, to: match.range.lowerBound)
            let rangeEndIndex = chapter.rawContent.distance(from: chapter.rawContent.startIndex, to: match.range.upperBound)
            
            for i in rangeStartIndex..<rangeEndIndex {
                characterMap[i].entry = match.entry
            }
        }
        
        // Now, build the lines of components from this character map.
        var lines: [[TextComponent]] = []
        var currentLine: [TextComponent] = []
        
        var currentText = ""
        var currentEntry: GlossaryEntry? = nil
        
        for (char, entry) in characterMap {
            if char.isNewline {
                // End the current component if there is one
                if !currentText.isEmpty {
                    if let entry = currentEntry {
                        currentLine.append(.glossary(text: currentText, entry: entry))
                    } else {
                        currentLine.append(.plain(currentText))
                    }
                }
                // Finalize the current line and start a new one
                lines.append(currentLine)
                currentLine = []
                currentText = ""
                currentEntry = nil
                continue
            }
            
            // If the entry type changes (or starts/ends), finalize the previous component
            if entry?.id != currentEntry?.id {
                if !currentText.isEmpty {
                    if let entry = currentEntry {
                        currentLine.append(.glossary(text: currentText, entry: entry))
                    } else {
                        currentLine.append(.plain(currentText))
                    }
                }
                currentText = ""
                currentEntry = entry
            }
            
            // Append the character to the current component's text
            currentText.append(char)
        }
        
        // Add the very last component and line
        if !currentText.isEmpty {
            if let entry = currentEntry {
                currentLine.append(.glossary(text: currentText, entry: entry))
            } else {
                currentLine.append(.plain(currentText))
            }
        }
        lines.append(currentLine)
        
        return lines
    }

    var body: some View {
        HSplitView {
            // --- Left Panel: Source Text ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Source: \(chapter.project?.sourceLanguage ?? "")")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                // Pass the generated lines to our new HighlightedTextView
                HighlightedTextView(lines: textLines)
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
