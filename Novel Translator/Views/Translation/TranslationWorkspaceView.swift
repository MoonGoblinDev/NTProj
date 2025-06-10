import SwiftUI
import SwiftData

struct TranslationWorkspaceView: View {
    // --- NEW IMPLEMENTATION ---
    // The view now receives the complete, optional Chapter object directly.
    // It's a simple 'let' constant because the parent view controls which chapter it is.
    // The chapter itself is an @Observable model, so its properties can still be changed.
    let chapter: Chapter?
    
    // A computed property to create a non-optional binding for the TextEditor.
    // This safely handles the cases where 'chapter' or 'translatedContent' is nil.
    private var translatedContentBinding: Binding<String> {
        Binding(
            get: { self.chapter?.translatedContent ?? "" },
            set: {
                // Ensure we don't try to set a value if the chapter is nil
                if self.chapter != nil {
                    self.chapter?.translatedContent = $0
                }
            }
        )
    }

    var body: some View {
        // The body now directly uses the 'chapter' property passed from ContentView
        if let chapter = self.chapter {
            VStack(spacing: 0) {
                HSplitView {
                    // Left Panel: Raw Content
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Source: \(chapter.project?.sourceLanguage ?? "")")
                            .font(.headline)
                            .padding([.horizontal, .top])
                        
                        TextEditor(text: .constant(chapter.rawContent))
                            .font(.system(.body, design: .serif))
                            .padding(.horizontal, 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: .textBackgroundColor))
                    }
                    
                    // Right Panel: Translated Content
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Translation: \(chapter.project?.targetLanguage ?? "")")
                            .font(.headline)
                            .padding([.horizontal, .top])
                        
                        TextEditor(text: translatedContentBinding)
                            .font(.system(.body, design: .serif))
                            .padding(.horizontal, 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: .textBackgroundColor))
                    }
                }
            }
            .navigationTitle("Ch. \(chapter.chapterNumber): \(chapter.title)")
            .toolbar {
                 ToolbarItem(placement: .primaryAction) {
                    Button("Translate", systemImage: "sparkles") {
                        // TODO: Trigger translation logic
                    }
                    .disabled(chapter.rawContent.isEmpty)
                }
            }
        } else {
            // This view is shown when 'chapter' is nil
            ContentUnavailableView(
                "No Chapter Selected",
                systemImage: "text.book.closed",
                description: Text("Select a chapter from the list in the sidebar to begin editing.")
            )
        }
    }
}
