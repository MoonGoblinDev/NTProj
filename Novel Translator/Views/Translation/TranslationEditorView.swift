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
    @ObservedObject var projectManager: ProjectManager
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
                HStack{
                    if let project = projectManager.currentProject {
                        Text("Source: \(project.sourceLanguage)")
                            .font(.headline)
                    }
                    Spacer()
                    TokenCounterView(text: String(sourceText.characters), projectManager: projectManager, autoCount: true)
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
                    if let project = projectManager.currentProject {
                        Text("Translation: \(project.targetLanguage)")
                            .font(.headline)
                    }
                    Spacer()
                    TokenCounterView(text: String(translatedText.characters), projectManager: projectManager, autoCount: false)
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
