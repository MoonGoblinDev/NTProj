import SwiftUI
import SwiftData

struct TranslationWorkspaceView: View {
    // The main data object for the editor
    let chapter: Chapter?
    
    // Data required for the new toolbar
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    // State to manage showing the "Create Project" sheet
    @State private var isCreatingProject = false

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
        Group {
            if let chapter = self.chapter {
                // Main editor view when a chapter is selected
                VStack(spacing: 0) {
                    HSplitView {
                        // --- Left Panel: Source Text ---
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Source: \(chapter.project?.sourceLanguage ?? "")")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            TextEditor(text: .constant(chapter.rawContent))
                                .font(.system(.body, design: .serif))
                                .padding(.horizontal, 5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(nsColor: .textBackgroundColor))
                        }
                        
                        // --- Right Panel: Translated Text ---
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Translation: \(chapter.project?.targetLanguage ?? "")")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            TextEditor(text: translatedContentBinding)
                                .font(.system(.body, design: .serif))
                                .padding(.horizontal, 5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(nsColor: .textBackgroundColor))
                        }
                    }
                }
                .navigationTitle("")
                
            } else {
                // Placeholder view when no chapter is selected
                ContentUnavailableView(
                    "No Chapter Selected",
                    systemImage: "text.book.closed",
                    description: Text("Select a chapter from the list in the sidebar.")
                )
            }
        }
        .toolbar{
            // --- The New Toolbar Layout ---
            ToolbarItemGroup(placement: .navigation) {
                // The project selector now lives here.
                ProjectSelectorView(
                    projects: projects,
                    selectedProjectID: $selectedProjectID,
                    onAddProject: {
                        isCreatingProject = true
                    }
                )
                .frame(minWidth: 200, idealWidth: 250) // Give it some space
            }
            ToolbarItemGroup(placement: .primaryAction) {
                // The main action button for the workspace
                Button("Translate", systemImage: "sparkles") {
                    // TODO: Trigger translation logic for the current chapter
                    print("Translate button clicked for chapter: \(chapter?.title ?? "None")")
                }
                .disabled(chapter == nil || chapter?.rawContent.isEmpty == true)
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            // Present the CreateProjectView sheet when triggered from the toolbar
            CreateProjectView()
        }
    }
}
