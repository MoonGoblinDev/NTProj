import SwiftUI

struct TranslationWorkspaceView: View {
    // Environment Objects
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    // Project Data
    @ObservedObject var project: TranslationProject
    
    // View Models & Services
    @State private var viewModel: TranslationViewModel!
    private let glossaryMatcher = GlossaryMatcher()
    
    // View State
    @State private var isPresetsViewPresented = false
    @State private var isPromptPreviewPresented = false
    @State private var promptPreviewText = ""
    @State private var isConfigPopoverShown = false
    
    // Glossary State
    @State private var entryToDisplay: GlossaryEntry?
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    // In-Editor Search State
    @State private var isEditorSearchActive = false
    @State private var editorSearchQuery = ""
    @State private var editorSearchResults: [NSRange] = []
    @State private var currentEditorSearchResultIndex: Int?
    
    // Computed Properties for active chapter/state
    private var activeChapter: Chapter? {
        guard let activeID = workspaceViewModel.activeChapterID else { return nil }
        return workspaceViewModel.fetchChapter(with: activeID)
    }

    private var activeEditorState: ChapterEditorState? {
        guard let activeID = workspaceViewModel.activeChapterID else { return nil }
        return workspaceViewModel.editorStates[activeID]
    }
    
    private var selectedPresetName: String {
        if let presetID = projectManager.settings.selectedPromptPresetID,
           let preset = projectManager.settings.promptPresets.first(where: { $0.id == presetID }) {
            return preset.name
        }
        return "Default Prompt"
    }

    var body: some View {
        let mainContent = ZStack {
            VStack(spacing: 0) {
                editorOrPlaceholder
            }
            
            if viewModel?.isTranslating == true {
                loadingOverlay
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                ProjectSelectorView()
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isPresetsViewPresented = true
                } label: {
                    Label("Manage Prompts", systemImage: "text.quote")
                }
                
                Menu {
                    Picker("Prompt Preset", selection: $projectManager.settings.selectedPromptPresetID) {
                        Text("Default Prompt").tag(nil as UUID?)
                        Divider()
                        ForEach(projectManager.settings.promptPresets.sorted(by: { $0.createdDate < $1.createdDate })) { preset in
                            Text(preset.name).tag(preset.id as UUID?)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: projectManager.settings.selectedPromptPresetID) { _, _ in projectManager.saveSettings() }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPresetName)
                            .lineLimit(1)
                    }
                }
                .menuIndicator(.visible)
                .fixedSize()
                
                Divider()
                
                Menu {
                    ForEach(projectManager.settings.apiConfigurations.filter { !$0.enabledModels.isEmpty }) { config in
                        Section(config.provider.displayName) {
                            ForEach(config.enabledModels, id: \.self) { modelName in
                                Button {
                                    projectManager.settings.selectedProvider = config.provider
                                    projectManager.settings.selectedModel = modelName
                                    projectManager.saveSettings()
                                } label: {
                                    HStack {
                                        Text(modelName)
                                        if projectManager.settings.selectedProvider == config.provider && projectManager.settings.selectedModel == modelName {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(projectManager.settings.selectedModel.isEmpty ? "Select Model" : projectManager.settings.selectedModel)
                            .lineLimit(1)
                    }
                }
                .menuIndicator(.visible)
                .fixedSize()
                .disabled(projectManager.settings.apiConfigurations.allSatisfy { $0.enabledModels.isEmpty })
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel()
            }
            updateSourceHighlights()
        }
        .onChange(of: viewModel?.translationText) { _, newText in
            if let text = newText, let state = activeEditorState {
                state.updateTranslation(newText: text)
            }
        }
        .onChange(of: activeChapter?.id) {
            updateSourceHighlights()
            resetEditorSearch()
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
            if let foundEntry = project.glossaryEntries.first(where: { $0.id == newID }) {
                self.entryToDisplay = foundEntry
            }
        }
        .onChange(of: editorSearchQuery) { _,_ in updateEditorSearch() }
        .onChange(of: appContext.searchResultToHighlight) { _, result in
            handleSearchResultNavigation(result)
        }
        
        return mainContent
            .sheet(isPresented: $isPresetsViewPresented) {
                PromptPresetsView(projectManager: projectManager)
            }
            .sheet(isPresented: $isPromptPreviewPresented) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Generated Prompt Preview")
                            .font(.title2)
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
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    Divider().padding(.top)

                    HStack {
                        Spacer()
                        Button("Done") {
                            isPromptPreviewPresented = false
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                    .padding()
                }
                .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
            }
            .sheet(isPresented: $appContext.isSheetPresented, onDismiss: { appContext.glossaryEntryToEditID = nil }) {
                if let entry = entryToDisplay,
                   let index = project.glossaryEntries.firstIndex(where: { $0.id == entry.id }) {
                    NavigationStack {
                        GlossaryDetailView(entry: $project.glossaryEntries[index], project: project, isCreating: false)
                    }
                } else {
                    Text("Error: Could not find glossary item.").padding()
                }
            }
            .alert("Translation Error", isPresented: .constant(viewModel?.errorMessage != nil), actions: {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel?.errorMessage ?? "An unknown error occurred.")
            })
            .alert(
                "Unsaved Changes",
                isPresented: $workspaceViewModel.isCloseChapterAlertPresented,
                presenting: workspaceViewModel.chapterIDToClose
            ) { _ in
                Button("Save Chapter") {
                    workspaceViewModel.saveAndCloseChapter()
                }
                Button("Discard Changes", role: .destructive) {
                    workspaceViewModel.discardAndCloseChapter()
                }
                Button("Cancel", role: .cancel) { }
            } message: { chapterID in
                let title = workspaceViewModel.fetchChapter(with: chapterID)?.title ?? "this chapter"
                Text("Do you want to save the changes you made to \"\(title)\"?\n\nYour changes will be lost if you don't save them.")
            }
    }
    
    @ViewBuilder private var editorOrPlaceholder: some View {
        if let chapter = activeChapter, let editorState = activeEditorState {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ChapterTabsView(workspaceViewModel: workspaceViewModel, project: project)
                    ZStack{
                        TranslationEditorView(
                            sourceText: .init(get: { editorState.sourceAttributedText }, set: { editorState.sourceAttributedText = $0 }),
                            translatedText: .init(get: { editorState.translatedAttributedText }, set: { editorState.translatedAttributedText = $0 }),
                            sourceSelection: .init(get: { editorState.sourceSelection }, set: { editorState.sourceSelection = $0 }),
                            translatedSelection: .init(get: { editorState.translatedSelection }, set: { editorState.translatedSelection = $0 }),
                            projectManager: projectManager,
                            chapter: chapter,
                            isDisabled: viewModel.isTranslating
                        )
                        VStack{
                            Spacer()
                            HStack {
                                Spacer()
                            
                                Button {
                                    isConfigPopoverShown.toggle()
                                } label: {
                                    Label("Config", systemImage: "gearshape")
                                }
                                .tint(.gray)
                                .buttonStyle(.borderedProminent)
                                .popover(isPresented: $isConfigPopoverShown) {
                                    VStack {
                                        Toggle("Force Line Count Sync", isOn: $project.translationConfig.forceLineCountSync)
                                            .onChange(of: project.translationConfig.forceLineCountSync) { _, _ in
                                                project.lastModifiedDate = Date()
                                                projectManager.isProjectDirty = true
                                            }
                                    }
                                    .padding()
                                }
                                .help("Advanced translation settings")
                                .onHover { isHovering in
                                    if isHovering {
                                        NSCursor.pointingHand.set()
                                    } else {
                                        NSCursor.arrow.set()
                                    }
                                }
                                
                                Button("Prompt Preview", systemImage: "sparkles.square.filled.on.square") {
                                    generatePromptPreview()
                                }
                                .tint(.gray)
                                .buttonStyle(.borderedProminent)
                                .help("Show the final prompt that will be sent to the AI")
                                .disabled(chapter.rawContent.isEmpty)
                                .onHover { isHovering in
                                    if isHovering {
                                        NSCursor.pointingHand.set()
                                    } else {
                                        NSCursor.arrow.set()
                                    }
                                }
                                
                                Button("Translate", systemImage: "sparkles") {
                                    Task {
                                        await viewModel.streamTranslateChapter(project: project, chapter: chapter, settings: projectManager.settings)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(activeChapter == nil || chapter.rawContent.isEmpty == true || viewModel?.isTranslating == true)
                                .onHover { isHovering in
                                    if isHovering {
                                        NSCursor.pointingHand.set()
                                    } else {
                                        NSCursor.arrow.set()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }

                if isEditorSearchActive {
                    EditorSearchView(
                        searchQuery: $editorSearchQuery,
                        totalResults: editorSearchResults.count,
                        currentResultIndex: $currentEditorSearchResultIndex,
                        onFindNext: { findNextMatch() },
                        onFindPrevious: { findPreviousMatch() },
                        onClose: {
                            isEditorSearchActive = false
                            editorSearchQuery = ""
                            updateEditorSearch()
                        }
                    )
                    .padding(.top, 45) // Position below tabs
                }
            }
            .background(
                Button("") {
                    isEditorSearchActive.toggle()
                }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            )
            
        } else {
            ContentUnavailableView(
                "No Chapter Selected",
                systemImage: "text.book.closed",
                description: Text("Select a chapter from the list in the sidebar.")
            )
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

    private func handleSelectionChange(_ selection: NSRange?) {
        guard let selection, selection.length == 0, let state = activeEditorState else { return }
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: String(state.sourceAttributedText.characters))) }) {
            appContext.glossaryEntryToEditID = match.entry.id
        }
    }
    
    private func generatePromptPreview() {
        guard let chapter = self.activeChapter else {
            self.promptPreviewText = "Error: Could not generate prompt. No active chapter."
            self.isPromptPreviewPresented = true
            return
        }

        let promptBuilder = PromptBuilder()
        let selectedPreset = projectManager.settings.promptPresets.first { $0.id == projectManager.settings.selectedPromptPresetID }
        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)

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

    private func updateSourceHighlights() {
        guard let editorState = activeEditorState else {
            self.glossaryMatches = []
            return
        }
        let stringToMatch = String(editorState.sourceAttributedText.characters)
        guard !stringToMatch.isEmpty else {
            self.glossaryMatches = []
            return
        }
        
        var mutableText = editorState.sourceAttributedText
        
        let fullRange = mutableText.startIndex..<mutableText.endIndex
        
        mutableText[fullRange].foregroundColor = NSColor.textColor
        mutableText[fullRange].underlineStyle = nil
        mutableText[fullRange].link = nil

        self.glossaryMatches = glossaryMatcher.detectTerms(in: stringToMatch, from: project.glossaryEntries)
        
        for match in glossaryMatches {
            if let range = Range(match.range, in: mutableText) {
                var highlightContainer = AttributeContainer()
                highlightContainer.underlineStyle = .single
                let categoryColor = match.entry.category.highlightColor
                highlightContainer.foregroundColor = NSColor(categoryColor)
                mutableText[range].mergeAttributes(highlightContainer, mergePolicy: .keepNew)
            }
        }
        
        editorState.sourceAttributedText = mutableText
        
        if isEditorSearchActive {
            applyEditorSearchHighlights()
        }
    }

    // MARK: - Search Handling Methods

    private func resetEditorSearch() {
        isEditorSearchActive = false
        editorSearchQuery = ""
        editorSearchResults = []
        currentEditorSearchResultIndex = nil
        updateEditorSearch()
    }

    private func updateEditorSearch() {
        guard let state = activeEditorState else {
            editorSearchResults = []
            currentEditorSearchResultIndex = nil
            return
        }
        
        guard !editorSearchQuery.isEmpty else {
            editorSearchResults = []
            currentEditorSearchResultIndex = nil
            applyEditorSearchHighlights(clearOnly: true)
            return
        }
        
        let fullText = String(state.sourceAttributedText.characters)
        do {
            let regex = try NSRegularExpression(pattern: editorSearchQuery, options: .caseInsensitive)
            let matches = regex.matches(in: fullText, range: NSRange(location: 0, length: fullText.utf16.count))
            editorSearchResults = matches.map { $0.range }
            
            if !editorSearchResults.isEmpty {
                currentEditorSearchResultIndex = 0
                navigateToMatch(at: 0)
            } else {
                currentEditorSearchResultIndex = nil
            }
            applyEditorSearchHighlights()
        } catch {
            editorSearchResults = []
            currentEditorSearchResultIndex = nil
            applyEditorSearchHighlights(clearOnly: true)
        }
    }
    
    private func findNextMatch() {
        guard let currentIndex = currentEditorSearchResultIndex, !editorSearchResults.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % editorSearchResults.count
        currentEditorSearchResultIndex = nextIndex
        navigateToMatch(at: nextIndex)
    }

    private func findPreviousMatch() {
        guard let currentIndex = currentEditorSearchResultIndex, !editorSearchResults.isEmpty else { return }
        let prevIndex = (currentIndex - 1 + editorSearchResults.count) % editorSearchResults.count
        currentEditorSearchResultIndex = prevIndex
        navigateToMatch(at: prevIndex)
    }
    
    private func navigateToMatch(at index: Int) {
        guard let state = activeEditorState, index < editorSearchResults.count else { return }
        let range = editorSearchResults[index]
        state.sourceSelection = range
    }
    
    private func applyEditorSearchHighlights(clearOnly: Bool = false) {
        guard let state = activeEditorState else { return }

        var attributedString = state.sourceAttributedText
        let entireRange = attributedString.startIndex..<attributedString.endIndex
        
        // Clear previous search highlights across the entire string.
        attributedString[entireRange].backgroundColor = nil

        // If we're only clearing highlights (e.g., search term is empty), we're done.
        if clearOnly {
            state.sourceAttributedText = attributedString
            return
        }
        
        // Apply standard highlight to all matches.
        for range in editorSearchResults {
            if let swiftRange = Range(range, in: attributedString) {
                attributedString[swiftRange].backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3)
            }
        }

        // Apply distinct highlight to the current match.
        if let currentIndex = currentEditorSearchResultIndex, currentIndex < editorSearchResults.count {
            let currentRange = editorSearchResults[currentIndex]
            if let swiftRange = Range(currentRange, in: attributedString) {
                attributedString[swiftRange].backgroundColor = NSColor.systemOrange.withAlphaComponent(0.5)
            }
        }
        
        state.sourceAttributedText = attributedString
    }

    private func handleSearchResultNavigation(_ result: SearchResultItem?) {
        guard let result = result else { return }
        
        workspaceViewModel.openChapter(id: result.chapterID)
        
        Task {
            while workspaceViewModel.activeChapterID != result.chapterID {
                await Task.yield()
            }
            
            guard let state = self.activeEditorState else { return }
            
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
