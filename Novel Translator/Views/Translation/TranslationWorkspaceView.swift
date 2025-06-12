import SwiftUI
import SwiftData

struct TranslationWorkspaceView: View {
    // Access the shared state from the environment.
    @EnvironmentObject private var appContext: AppContext
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedChapterID: PersistentIdentifier?
    @Query private var chapters: [Chapter]
    
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    @State private var isCreatingProject = false
    @State private var viewModel: TranslationViewModel!
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    // This state is used to hold the found glossary entry for the sheet to display.
    @State private var entryToDisplay: GlossaryEntry?

    private let glossaryMatcher = GlossaryMatcher()

    // A computed property to get the currently selected chapter.
    private var chapter: Chapter? {
        chapters.first
    }
    
    // A computed property to get the currently selected project.
    private var project: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
    // The initializer creates a dynamic @Query based on the selected chapter ID.
    init(selectedChapterID: Binding<PersistentIdentifier?>, projects: [TranslationProject], selectedProjectID: Binding<PersistentIdentifier?>) {
        _selectedChapterID = selectedChapterID
        self.projects = projects
        _selectedProjectID = selectedProjectID
        
        let id = selectedChapterID.wrappedValue
        let predicate = id.map { finalID in
            #Predicate<Chapter> { $0.persistentModelID == finalID }
        } ?? #Predicate<Chapter> { _ in false }
        
        _chapters = Query(filter: predicate)
    }

    var body: some View {
        ZStack {
            editorOrPlaceholder
            
            if viewModel?.isTranslating == true {
                loadingOverlay
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                ProjectSelectorView(
                    projects: projects,
                    selectedProjectID: $selectedProjectID,
                    onAddProject: { isCreatingProject = true }
                )
                .frame(minWidth: 200, idealWidth: 250)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Translate", systemImage: "sparkles") {
                    Task {
                        await viewModel.streamTranslateChapter(chapter)
                    }
                }
                .disabled(chapter == nil || chapter?.rawContent.isEmpty == true || viewModel?.isTranslating == true)
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            CreateProjectView()
        }
        // The sheet's presentation is controlled by the AppContext's boolean flag.
        .sheet(isPresented: $appContext.isSheetPresented) {
            // This closure is called when the sheet is dismissed.
            // We clear the ID in the AppContext to reset the state.
            appContext.glossaryEntryToEditID = nil
        } content: {
            // The content of the sheet depends on the entry we found and stored locally.
            if let entry = entryToDisplay, let project = self.project {
                GlossaryDetailView(entry: entry, project: project)
            } else {
                // This fallback prevents a crash if something goes wrong.
                Text("Error: Could not find glossary item.")
                    .padding()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel(modelContext: modelContext)
            }
            updateViewsForChapter()
        }
        // When the selected chapter changes, update the editor content.
        .onChange(of: chapter?.id) {
            updateViewsForChapter()
        }
        // This is the reaction mechanism. It watches for changes in the AppContext.
        .onChange(of: appContext.glossaryEntryToEditID) { _, newID in
            guard let newID = newID else {
                // If the ID is cleared (e.g., on sheet dismiss), clear our local copy.
                entryToDisplay = nil
                return
            }
            
            // When the ID changes, find the corresponding entry in the current project.
            if let foundEntry = project?.glossaryEntries.first(where: { $0.id == newID }) {
                // Store the found entry locally for the sheet to use.
                self.entryToDisplay = foundEntry
            }
        }
        .alert("Translation Error", isPresented: .constant(viewModel?.errorMessage != nil), actions: {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel?.errorMessage ?? "An unknown error occurred.")
        })
    }

    /// This function is called whenever the chapter selection changes.
    /// It updates the translation text in the view model and re-calculates glossary matches.
    private func updateViewsForChapter() {
        viewModel?.setChapter(chapter)
        
        guard let chapter = chapter, let project = chapter.project else {
            self.glossaryMatches = []
            return
        }
        
        self.glossaryMatches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
    }

    /// A view builder that shows the editor if a chapter is selected, or a placeholder otherwise.
    @ViewBuilder
    private var editorOrPlaceholder: some View {
        if let chapter = self.chapter, self.viewModel != nil {
            TranslationEditorView(
                chapter: chapter,
                translatedContent: Binding(
                    get: { self.viewModel?.translationText ?? "" },
                    set: { self.viewModel?.translationText = $0 }
                ),
                matches: glossaryMatches,
                isDisabled: viewModel?.isTranslating ?? false
            )
        } else {
            ContentUnavailableView(
                "No Chapter Selected",
                systemImage: "text.book.closed",
                description: Text("Select a chapter from the list in the sidebar.")
            )
        }
    }
    
    /// A view builder for the loading indicator that appears during translation.
    @ViewBuilder
    private var loadingOverlay: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .padding()
            .background(.regularMaterial, in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding()
            .transition(.opacity.animation(.easeInOut))
    }
}
