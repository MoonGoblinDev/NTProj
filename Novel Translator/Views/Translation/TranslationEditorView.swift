import SwiftUI
import STTextViewSwiftUI
import STTextView

/// A dedicated view for the side-by-side translation editor, powered by STTextView.
struct TranslationEditorView: View {
    // Bindings to the attributed strings managed by the parent view.
    @Binding var sourceText: AttributedString
    @Binding var translatedText: AttributedString
    
    // Bindings for managing text selection (cursor position).
    @Binding var sourceSelection: NSRange?
    @Binding var translatedSelection: NSRange?
    
    let chapter: Chapter
    let isDisabled: Bool
    
    // The options are a nested type of the SwiftUI wrapper view.
    private let textViewOptions: TextView.Options = [
        .showLineNumbers,
        .wrapLines,
        .highlightSelectedLine
    ]
    
    var body: some View {
        HSplitView {
            // --- Left Panel: Source Text ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Source: \(chapter.project?.sourceLanguage ?? "")")
                    .font(.headline)
                    .padding([.horizontal, .top])
                
                TextView(
                    text: $sourceText,
                    selection: $sourceSelection,
                    options: textViewOptions
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // --- Right Panel: Translated Text ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Translation: \(chapter.project?.targetLanguage ?? "") (\(chapter.translationStatus.rawValue))")
                    .font(.headline)
                    .padding([.horizontal, .top])
                
                TextView(
                    text: $translatedText,
                    selection: $translatedSelection,
                    options: textViewOptions
                )
                // REMOVED: .textViewFont() is no longer needed.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(isDisabled)
            }
        }
        .navigationTitle(chapter.title)
    }
}
