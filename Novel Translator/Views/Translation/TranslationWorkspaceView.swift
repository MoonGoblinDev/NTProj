import SwiftUI

struct TranslationWorkspaceView: View {
    // Environment
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    // Project Data
    @ObservedObject var project: TranslationProject
    
    // View Models
    @State private var viewModel: TranslationViewModel!
    
    // View State
    @State private var isPresetsViewPresented = false
    @State private var isPromptPreviewPresented = false
    @State private var promptPreviewText = ""
    
    // State passed to handlers
    @State private var entryToDisplay: GlossaryEntry?
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    // Computed binding for error alert
    private var isErrorAlertPresented: Binding<Bool> {
        Binding<Bool>(
            get: { viewModel?.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel?.errorMessage = nil }
            }
        )
    }

    var body: some View {
        let mainContent = ZStack {
            if viewModel != nil {
                EditorAreaView(
                    project: project,
                    translationViewModel: viewModel,
                    glossaryMatches: $glossaryMatches,
                    onShowPromptPreview: generatePromptPreview
                )
                .background {
                    // Compose the small, single-purpose logic handlers.
                    // This is the key to solving the compiler timeout issue.
                    TranslationTextChangeHandler(viewModel: viewModel)
                    GlossaryLogicHandler(
                        entryToDisplay: $entryToDisplay,
                        glossaryMatches: $glossaryMatches
                    )
                    SearchNavigationHandler()
                }
            } else {
                initialPlaceholderView
            }
            
            if viewModel?.isTranslating == true {
                loadingOverlay
            }
        }
        .navigationTitle("")
        .toolbar {
            if viewModel != nil {
                TranslationWorkspaceToolbar(
                    projectManager: projectManager,
                    isPresetsViewPresented: $isPresetsViewPresented
                )
            }
        }
        
        return mainContent
            .onAppear {
                if viewModel == nil {
                    viewModel = TranslationViewModel()
                }
            }
            .sheet(isPresented: $isPresetsViewPresented) {
                PromptPresetsView(projectManager: projectManager)
            }
            .sheet(isPresented: $isPromptPreviewPresented) {
                promptPreviewSheet
            }
            .sheet(isPresented: $appContext.isSheetPresented, onDismiss: { appContext.glossaryEntryToEditID = nil }) {
                glossaryDetailSheet
            }
            .alert("Translation Error", isPresented: isErrorAlertPresented, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(viewModel?.errorMessage ?? "An unknown error occurred.")
            })
            .alert(
                "Unsaved Changes",
                isPresented: $workspaceViewModel.isCloseChapterAlertPresented,
                presenting: workspaceViewModel.chapterIDToClose
            ) { _ in
                unsavedChangesAlertButtons
            } message: { chapterID in
                let title = workspaceViewModel.fetchChapter(with: chapterID)?.title ?? "this chapter"
                Text("Do you want to save the changes you made to \"\(title)\"?\n\nYour changes will be lost if you don't save them.")
            }
    }
    
    // MARK: - Helper Methods
    
    private func generatePromptPreview() {
        guard let chapter = workspaceViewModel.activeChapter else {
            self.promptPreviewText = "Error: Could not generate prompt. No active chapter."
            self.isPromptPreviewPresented = true
            return
        }

        let promptBuilder = PromptBuilder()
        let selectedPreset = projectManager.settings.promptPresets.first { $0.id == projectManager.settings.selectedPromptPresetID }
        let matches = GlossaryMatcher().detectTerms(in: chapter.rawContent, from: project.glossaryEntries)

        self.promptPreviewText = promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: project.sourceLanguage,
            targetLanguage: project.targetLanguage,
            preset: selectedPreset,
            config: project.translationConfig
        )
        self.isPromptPreviewPresented = true
    }
    
    // MARK: - Extracted Subviews
    
    private var initialPlaceholderView: some View {
        ContentUnavailableView("No Chapter Selected", systemImage: "text.book.closed", description: Text("Select a chapter from the list in the sidebar."))
    }
    
    private var loadingOverlay: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .padding()
            .background(.regularMaterial, in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding()
            .transition(.opacity.animation(.easeInOut))
    }
    
    private var promptPreviewSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Generated Prompt Preview").font(.title2)
                Spacer()
                TokenCounterView(text: promptPreviewText, projectManager: projectManager, autoCount: true)
            }
            .padding()
            
            ScrollView {
                Text(promptPreviewText)
                    .font(.body.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor)).cornerRadius(8).padding(.horizontal)

            Divider().padding(.top)

            HStack {
                Spacer()
                Button("Done") { isPromptPreviewPresented = false }.keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
    }
    
    private var glossaryDetailSheet: some View {
        Group {
            if let entry = entryToDisplay, let index = project.glossaryEntries.firstIndex(where: { $0.id == entry.id }) {
                NavigationStack {
                    GlossaryDetailView(entry: $project.glossaryEntries[index], project: project, isCreating: false)
                }
            } else {
                Text("Error: Could not find glossary item.").padding()
            }
        }
    }
    
    @ViewBuilder private var unsavedChangesAlertButtons: some View {
        Button("Save Chapter") { workspaceViewModel.saveAndCloseChapter() }
        Button("Discard Changes", role: .destructive) { workspaceViewModel.discardAndCloseChapter() }
        Button("Cancel", role: .cancel) { }
    }
}

// MARK: - Private Logic Handler Views

/// Handles updates to the translation text editor.
private struct TranslationTextChangeHandler: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    let viewModel: TranslationViewModel

    var body: some View {
        EmptyView()
            .onChange(of: viewModel.translationText) { _, newText in
                if let state = workspaceViewModel.activeEditorState {
                    state.updateTranslation(newText: newText)
                }
            }
    }
}

/// Handles all logic related to the glossary (highlighting, selection, editing).
private struct GlossaryLogicHandler: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    @Binding var entryToDisplay: GlossaryEntry?
    @Binding var glossaryMatches: [GlossaryMatch]

    private let glossaryMatcher = GlossaryMatcher()
    private var project: TranslationProject? { workspaceViewModel.project }
    private var activeChapter: Chapter? { workspaceViewModel.activeChapter }

    var body: some View {
        EmptyView()
            .onAppear { updateGlossaryMatches() }
            .onChange(of: activeChapter?.id) { updateGlossaryMatches() }
            .onChange(of: workspaceViewModel.activeEditorState?.sourceAttributedText) { updateGlossaryMatches() }
            .onChange(of: workspaceViewModel.activeEditorState?.sourceSelection) { _, newSelection in handleGlossarySelection(newSelection) }
            .onChange(of: appContext.glossaryEntryToEditID) { _, newID in handleGlossaryIDChange(newID) }
    }
    
    private func updateGlossaryMatches() {
        guard let state = workspaceViewModel.activeEditorState, let proj = project else {
            glossaryMatches = []; return
        }
        let text = String(state.sourceAttributedText.characters)
        glossaryMatches = text.isEmpty ? [] : glossaryMatcher.detectTerms(in: text, from: proj.glossaryEntries)
    }
    
    private func handleGlossarySelection(_ selection: NSRange?) {
        guard let state = workspaceViewModel.activeEditorState, let selection = selection, selection.length == 0 else { return }
        let text = String(state.sourceAttributedText.characters)
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: text)) }) {
             appContext.glossaryEntryToEditID = match.entry.id
        }
    }
    
    private func handleGlossaryIDChange(_ newID: UUID?) {
        guard let proj = project, let newID = newID else {
            entryToDisplay = nil; return
        }
        entryToDisplay = proj.glossaryEntries.first(where: { $0.id == newID })
    }
}

/// Handles navigation from project-wide search results.
private struct SearchNavigationHandler: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel

    var body: some View {
        EmptyView()
            .onChange(of: appContext.searchResultToHighlight) { _, result in
                handleSearchResultNavigation(result)
            }
    }

    private func handleSearchResultNavigation(_ result: SearchResultItem?) {
        guard let result = result else { return }
        
        workspaceViewModel.openChapter(id: result.chapterID)
        
        Task {
            while workspaceViewModel.activeChapterID != result.chapterID { await Task.yield() }
            
            guard let state = workspaceViewModel.activeEditorState else { return }
            
            let fullText = (result.editorType == .source) ? String(state.sourceAttributedText.characters) : String(state.translatedAttributedText.characters)
            let lines = fullText.components(separatedBy: .newlines)
            
            guard result.lineNumber - 1 < lines.count else { return }
            
            let charactersUpToLine = lines.prefix(result.lineNumber - 1).map { $0.utf16.count + 1 }.reduce(0, +)
            let absoluteLocation = charactersUpToLine + result.matchRangeInLine.location
            let finalRange = NSRange(location: absoluteLocation, length: result.matchRangeInLine.length)
            
            if result.editorType == .source {
                state.sourceSelection = finalRange
            } else {
                state.translatedSelection = finalRange
            }
            appContext.searchResultToHighlight = nil
        }
    }
}
