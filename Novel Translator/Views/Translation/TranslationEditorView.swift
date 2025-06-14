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
    
    // Models
    let chapter: Chapter
    let project: TranslationProject // Add project
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
                HStack{
                    // FIX: Use the passed-in project object
                    Text("Source: \(project.sourceLanguage)")
                        .font(.headline)
                    Spacer()
                    // FIX: Pass the project object to the counter
                    TokenCounterView(text: String(sourceText.characters), project: project, autoCount: true)
                }
                .frame(height: 10)
                .padding()
                
                TextView(
                    text: $sourceText,
                    selection: $sourceSelection,
                    options: textViewOptions
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // --- Right Panel: Translated Text ---
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    // FIX: Use the passed-in project object
                    Text("Translation: \(project.targetLanguage)")
                        .font(.headline)
                    Spacer()
                    // FIX: Pass the project object to the counter
                    TokenCounterView(text: String(translatedText.characters), project: project, autoCount: false)
                }
                .frame(height: 10)
                .padding()
                
                TextView(
                    text: $translatedText,
                    selection: $translatedSelection,
                    options: textViewOptions
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(isDisabled)
            }
        }
        .navigationTitle("")
    }
}
