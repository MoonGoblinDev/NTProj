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
    @State private var isGeneratingPromptPreview = false
    
    // State passed to handlers
    @State private var entryToDisplay: GlossaryEntry?
    
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
                    onShowPromptPreview: generatePromptPreview
                )
                .environmentObject(appContext) // Pass AppContext to EditorAreaView
                .background {
                    // Compose the small, single-purpose logic handlers.
                    TranslationTextChangeHandler(viewModel: viewModel)
                    GlossaryPopupHandler(entryToDisplay: $entryToDisplay)
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
        isGeneratingPromptPreview = true
        promptPreviewText = "" // Clear old text to ensure loading state is clean
        isPromptPreviewPresented = true
        
        Task {
            // Capture data for the background task. Accessing observed objects is fine.
            guard let chapter = workspaceViewModel.activeChapter else {
                await MainActor.run {
                    self.promptPreviewText = "Error: Could not generate prompt. No active chapter."
                    self.isGeneratingPromptPreview = false
                }
                return
            }
            
            let generatedText = await generatePromptText(
                chapter: chapter,
                config: project.translationConfig,
                allChapters: project.chapters,
                glossary: project.glossaryEntries,
                sourceLang: project.sourceLanguage,
                targetLang: project.targetLanguage,
                settings: projectManager.settings
            )
            
            // Update UI on main thread
            await MainActor.run {
                self.promptPreviewText = generatedText
                self.isGeneratingPromptPreview = false
            }
        }
    }

    private func generatePromptText(
        chapter: Chapter,
        config: TranslationProject.TranslationConfig,
        allChapters: [Chapter],
        glossary: [GlossaryEntry],
        sourceLang: String,
        targetLang: String,
        settings: AppSettings
    ) async -> String {
        // This heavy work is now done in a background-compatible way.
        var previousContextText: String? = nil
        if config.includePreviousContext {
            let sortedChapters = allChapters.sorted { $0.chapterNumber < $1.chapterNumber }
            if let currentChapterIndex = sortedChapters.firstIndex(where: { $0.id == chapter.id }) {
                let count = config.previousContextChapterCount
                let startIndex = max(0, currentChapterIndex - count)
                let endIndex = currentChapterIndex
                
                if startIndex < endIndex {
                    let contextChapters = sortedChapters[startIndex..<endIndex]
                    previousContextText = contextChapters
                        .compactMap { $0.translatedContent }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n\n---\n\n")
                }
            }
        }

        let promptBuilder = PromptBuilder()
        let selectedPreset = settings.promptPresets.first { $0.id == settings.selectedPromptPresetID }
        let matches = GlossaryMatcher().detectTerms(in: chapter.rawContent, from: glossary)

        return promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: sourceLang,
            targetLanguage: targetLang,
            preset: selectedPreset,
            config: config,
            previousContext: previousContextText
        )
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
                if !isGeneratingPromptPreview {
                    TokenCounterView(text: promptPreviewText, projectManager: projectManager, autoCount: true)
                }
            }
            .padding()
            
            if isGeneratingPromptPreview {
                ProgressView("Generating prompt...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(promptPreviewText)
                        .font(.body.monospaced())
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .background(Color(NSColor.textBackgroundColor)).cornerRadius(8).padding(.horizontal)
            }

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
                        .environmentObject(projectManager)
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

/// Handles displaying the glossary detail sheet when an item is selected globally.
private struct GlossaryPopupHandler: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    @Binding var entryToDisplay: GlossaryEntry?
    private var project: TranslationProject? { workspaceViewModel.project }

    var body: some View {
        EmptyView()
            .onChange(of: appContext.glossaryEntryToEditID) { _, newID in
                handleGlossaryIDChange(newID)
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
