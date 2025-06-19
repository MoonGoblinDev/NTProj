import SwiftUI
import STTextViewSwiftUI
import STTextView

/// A dedicated view for the side-by-side translation editor, powered by STTextView.
/// This view now acts as a container for the editor "chrome" and the isolated EditorPane.
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
    
    var body: some View {
        // The main layout is now a VStack containing headers and the isolated editor.
        VStack(spacing: 0) {
            // Header bar for both editors
            HStack(spacing: 0) {
                // Left Panel Header
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        if let project = projectManager.currentProject {
                            Text("Source: \(project.sourceLanguage)")
                                .font(.headline)
                        }
                        Spacer()
                        TokenCounterView(text: String(sourceText.characters), projectManager: projectManager, autoCount: true)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Right Panel Header
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        if let project = projectManager.currentProject {
                            Text("Translation: \(project.targetLanguage)")
                                .font(.headline)
                        }
                        Spacer()
                        TokenCounterView(text: String(translatedText.characters), projectManager: projectManager, autoCount: false)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .frame(height: 38)
            .background(.background.secondary)

            Divider()

            // The stable, isolated editor pane.
            EditorPane(
                sourceText: $sourceText,
                translatedText: $translatedText,
                sourceSelection: $sourceSelection,
                translatedSelection: $translatedSelection,
                isDisabled: isDisabled
            )
            Rectangle()
                .fill(.background)
                .frame(height: 45)
                
                
        }
        .navigationTitle("") // This can be removed as it's not in a NavigationView here
    }
}

#Preview("Editor Area") {
    let mocks = PreviewMocks.shared
    return mocks.provide(to: EditorAreaView(
        project: mocks.project,
        translationViewModel: mocks.translationViewModel,
        onShowPromptPreview: {}
    ))
}
