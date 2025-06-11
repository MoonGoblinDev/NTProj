import SwiftUI
import SwiftData

struct TranslationWorkspaceView: View {
    // Access the shared context from the environment.
    @EnvironmentObject private var appContext: AppContext
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedChapterID: PersistentIdentifier?
    @Query private var chapters: [Chapter]
    
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    @State private var isCreatingProject = false
    @State private var viewModel: TranslationViewModel!
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    // This state is now used to *hold* the found entry, but not to *trigger* the sheet.
    @State private var entryToDisplay: GlossaryEntry?

    private let glossaryMatcher = GlossaryMatcher()

    private var chapter: Chapter? {
        chapters.first
    }
    
    private var project: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
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
        .toolbar { /* ... toolbar is unchanged ... */ }
        .sheet(isPresented: $isCreatingProject) {
            CreateProjectView()
        }
        // The sheet is now bound to the AppContext's boolean flag.
        .sheet(isPresented: $appContext.isSheetPresented) {
            // When the sheet is dismissed, clear the ID in the AppContext.
            appContext.glossaryEntryToEditID = nil
        } content: {
            // The content of the sheet depends on the entry we found.
            if let entry = entryToDisplay, let project = self.project {
                GlossaryDetailView(entry: entry, project: project)
            } else {
                // Fallback in case something goes wrong, prevents a crash.
                Text("Error: Could not find glossary item.")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel(modelContext: modelContext)
            }
            updateViewsForChapter()
        }
        .onChange(of: chapter?.id) {
            updateViewsForChapter()
        }
        // This is the new reaction mechanism.
        .onChange(of: appContext.glossaryEntryToEditID) { _, newID in
            guard let newID = newID else {
                // If the ID is cleared, nil out our local copy.
                entryToDisplay = nil
                return
            }
            
            // When the ID changes, find the corresponding entry in the current project.
            if let foundEntry = project?.glossaryEntries.first(where: { $0.id == newID }) {
                // Store it locally for the sheet to use.
                self.entryToDisplay = foundEntry
            }
        }
        .alert("Translation Error", isPresented: .constant(viewModel?.errorMessage != nil), actions: {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel?.errorMessage ?? "An unknown error occurred.")
        })
    }

    private func updateViewsForChapter() {
        viewModel?.setChapter(chapter)
        guard let chapter = chapter, let project = chapter.project else {
            self.glossaryMatches = []
            return
        }
        self.glossaryMatches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
    }

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
