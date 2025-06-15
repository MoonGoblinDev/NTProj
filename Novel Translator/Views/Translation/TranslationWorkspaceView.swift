import SwiftUI

struct TranslationWorkspaceView: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    @ObservedObject var project: TranslationProject
    
    @State private var isPresetsViewPresented = false
    @State private var isPromptPreviewPresented = false
    @State private var promptPreviewText = ""
    
    @State private var viewModel: TranslationViewModel!
    
    @State private var entryToDisplay: GlossaryEntry?
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    private let glossaryMatcher = GlossaryMatcher()
    
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
                        Button("Prompt Preview", systemImage: "sparkles.square.filled.on.square") {
                            generatePromptPreview()
                        }
                        .help("Show the final prompt that will be sent to the AI")
                        .disabled(chapter.rawContent.isEmpty)
                        
                        Button("Translate", systemImage: "sparkles") {
                            Task {
                                await viewModel.streamTranslateChapter(project: project, chapter: chapter, settings: projectManager.settings)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(activeChapter == nil || chapter.rawContent.isEmpty == true || viewModel?.isTranslating == true)
                    }
                    .padding()
                }
            }
            
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
        let glossaryMatcher = GlossaryMatcher()

        let selectedPreset = projectManager.settings.promptPresets.first { $0.id == projectManager.settings.selectedPromptPresetID }
        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)

        self.promptPreviewText = promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: project.sourceLanguage,
            targetLanguage: project.targetLanguage,
            preset: selectedPreset
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
        
        let fullNSRange = NSRange(location: 0, length: stringToMatch.utf16.count)
        guard let fullRange = Range(fullNSRange, in: mutableText) else { return }
        
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
    }
}
