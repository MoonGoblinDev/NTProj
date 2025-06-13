import SwiftUI
import SwiftData
import STTextViewSwiftUI

struct TranslationWorkspaceView: View {
    @EnvironmentObject private var appContext: AppContext
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkspaceViewModel.self) private var workspaceViewModel
    
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    @State private var isCreatingProject = false
    @State private var viewModel: TranslationViewModel!
    
    @State private var entryToDisplay: GlossaryEntry?
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    private let glossaryMatcher = GlossaryMatcher()
    
    private var project: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
    private var activeChapter: Chapter? {
        guard let activeID = workspaceViewModel.activeChapterID else { return nil }
        for p in projects {
            if let ch = p.chapters.first(where: { $0.id == activeID }) {
                return ch
            }
        }
        return nil
    }

    private var activeEditorState: ChapterEditorState? {
        guard let activeID = workspaceViewModel.activeChapterID else { return nil }
        return workspaceViewModel.editorStates[activeID]
    }
    
    init(projects: [TranslationProject], selectedProjectID: Binding<PersistentIdentifier?>) {
        self.projects = projects
        _selectedProjectID = selectedProjectID
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                editorOrPlaceholder
            }
            
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
                Button("Save", systemImage: "square.and.arrow.down") {
                    saveChanges()
                }
                .disabled(activeChapter == nil || viewModel.isTranslating || !(activeEditorState?.hasUnsavedChanges ?? true))
                
                Button("Translate", systemImage: "sparkles") {
                    Task {
                        await viewModel.streamTranslateChapter(activeChapter)
                    }
                }
                .disabled(activeChapter == nil || activeChapter?.rawContent.isEmpty == true || viewModel?.isTranslating == true)
            }
        }
        .sheet(isPresented: $isCreatingProject) { CreateProjectView() }
        .sheet(isPresented: $appContext.isSheetPresented, onDismiss: { appContext.glossaryEntryToEditID = nil }) {
            if let entry = entryToDisplay, let project = self.project {
                NavigationStack {
                    GlossaryDetailView(entry: entry, project: project)
                }
            } else {
                Text("Error: Could not find glossary item.").padding()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel?.translationText) { _, newText in
            if let text = newText, let state = activeEditorState {
                state.updateTranslation(newText: text)
            }
        }
        .onChange(of: activeEditorState?.sourceAttributedText) { oldValue, newValue in
            guard let oldVal = oldValue, let newVal = newValue else { return }
            if String(oldVal.characters) != String(newVal.characters) {
                 updateSourceHighlights()
            }
        }
        .onChange(of: activeEditorState?.sourceSelection) { _, newSelection in
            handleSelectionChange(newSelection)
        }
        .onChange(of: appContext.glossaryEntryToEditID) { _, newID in
            guard let newID = newID else {
                entryToDisplay = nil
                return
            }
            if let foundEntry = project?.glossaryEntries.first(where: { $0.id == newID }) {
                self.entryToDisplay = foundEntry
            }
        }
        .alert("Translation Error", isPresented: .constant(viewModel?.errorMessage != nil), actions: {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel?.errorMessage ?? "An unknown error occurred.")
        })
    }
    
    @ViewBuilder private var editorOrPlaceholder: some View {
        if let chapter = activeChapter, let editorState = activeEditorState {
            ChapterTabsView(workspaceViewModel: workspaceViewModel, projects: projects)
            TranslationEditorView(
                sourceText: .init(get: { editorState.sourceAttributedText }, set: { editorState.sourceAttributedText = $0 }),
                translatedText: .init(get: { editorState.translatedAttributedText }, set: { editorState.translatedAttributedText = $0 }),
                sourceSelection: .init(get: { editorState.sourceSelection }, set: { editorState.sourceSelection = $0 }),
                translatedSelection: .init(get: { editorState.translatedSelection }, set: { editorState.translatedSelection = $0 }),
                chapter: chapter,
                isDisabled: viewModel.isTranslating
            )
        } else if project != nil {
            ContentUnavailableView(
                "No Chapter Selected",
                systemImage: "text.book.closed",
                description: Text("Select a chapter from the list in the sidebar.")
            )
        } else {
            WelcomeView()
        }
    }
    
    @ViewBuilder private var loadingOverlay: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .padding()
            .background(.regularMaterial, in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding()
            .transition(.opacity.animation(.easeInOut))
    }
    
    private func saveChanges() {
        Task {
            do {
                try workspaceViewModel.saveChapter(id: workspaceViewModel.activeChapterID)
            } catch {
                viewModel.errorMessage = "Failed to save changes: \(error.localizedDescription)"
            }
        }
    }

    private func handleSelectionChange(_ selection: NSRange?) {
        guard let selection, selection.length == 0, let state = activeEditorState else { return }
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: String(state.sourceAttributedText.characters))) }) {
            appContext.glossaryEntryToEditID = match.entry.id
        }
    }

    private func updateSourceHighlights() {
        guard let project = project, let editorState = activeEditorState else {
            self.glossaryMatches = []
            return
        }
        let stringToMatch = String(editorState.sourceAttributedText.characters)
        guard !stringToMatch.isEmpty else {
            self.glossaryMatches = []
            return
        }
        
        // This is a complex operation that modifies the attributed string in place.
        var mutableText = editorState.sourceAttributedText
        
        let fullNSRange = NSRange(location: 0, length: stringToMatch.utf16.count)
        guard let fullRange = Range(fullNSRange, in: mutableText) else { return }
        
        mutableText[fullRange].foregroundColor = NSColor.textColor
        mutableText[fullRange].underlineStyle = nil
        mutableText[fullRange].link = nil

        self.glossaryMatches = glossaryMatcher.detectTerms(in: stringToMatch, from: project.glossaryEntries)

        var highlightContainer = AttributeContainer()
        highlightContainer.underlineStyle = .single
        highlightContainer.foregroundColor = NSColor(Color.gold)
        
        for match in glossaryMatches {
            if let range = Range(match.range, in: mutableText) {
                mutableText[range].mergeAttributes(highlightContainer, mergePolicy: .keepNew)
            }
        }
        
        // Assign the modified string back to the state.
        editorState.sourceAttributedText = mutableText
    }
}

// **FIX:** Re-add the missing extension.
extension Range where Bound == String.Index {
    func toNSRange(in string: String) -> NSRange {
        return NSRange(self, in: string)
    }
}
