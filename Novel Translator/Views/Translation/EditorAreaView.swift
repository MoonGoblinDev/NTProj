import SwiftUI

struct EditorAreaView: View {
    // Environment
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var appContext: AppContext
    
    // Local state for highlight management
    @State private var glossaryMatches: [GlossaryMatch] = []
    @State private var translatedGlossaryMatches: [GlossaryMatch] = []
    @State private var lastProcessedTextContent: String?
    @State private var lastProcessedTranslatedTextContent: String?
    private let glossaryMatcher = GlossaryMatcher()
    
    // Parent Models & State
    @ObservedObject var project: TranslationProject
    var translationViewModel: TranslationViewModel
    
    // Bindings from parent
    let onShowPromptPreview: () -> Void
    
    // Local State
    @State private var searchViewModel = EditorSearchViewModel()
    @State private var isEditorSearchActive = false
    @State private var isConfigPopoverShown = false
    @State private var isGlossaryExtractionPresented = false
    
    // New state for the popover-like view
    struct GlossaryInfo: Identifiable {
        let id = UUID() // For transition identity
        let entry: GlossaryEntry
        let isSourceTerm: Bool
    }
    @State private var activeGlossaryInfo: GlossaryInfo?
    
    // Computed Properties
    private var activeChapter: Chapter? {
        workspaceViewModel.activeChapter
    }
    
    private var activeEditorState: ChapterEditorState? {
        workspaceViewModel.activeEditorState
    }
    
    private var isSourceTextEmpty: Bool {
        guard let state = activeEditorState else { return true }
        // Use the explicit String initializer to get the content reliably.
        return String(state.sourceAttributedText.characters).isEmpty
    }
    
    private var isTranslatedTextEmpty: Bool {
        guard let state = activeEditorState else { return true }
        return String(state.translatedAttributedText.characters).isEmpty
    }
    
    var body: some View {
        if let chapter = activeChapter, let editorState = activeEditorState {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ChapterTabsView(workspaceViewModel: workspaceViewModel, project: project)
                    
                    editorWithButtons(chapter: chapter, editorState: editorState)
                }
                
                // The new glossary info popup view
                if let info = activeGlossaryInfo {
                    GlossaryPopupView(
                        info: info,
                        onOpenDetail: {
                            appContext.glossaryEntryIDForDetail = info.entry.id
                            withAnimation { activeGlossaryInfo = nil }
                        },
                        onDismiss: {
                            withAnimation { activeGlossaryInfo = nil }
                        }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                            // Initial load when the view appears for the first time
                            updateSourceGlossaryAndHighlights()
                            updateTranslatedGlossaryAndHighlights()
                        }
                        .onChange(of: activeChapter?.id) {
                            // When chapter changes, force a full recalculation
                            resetEditorSearch()
                            lastProcessedTextContent = nil
                            lastProcessedTranslatedTextContent = nil
                            updateSourceGlossaryAndHighlights()
                            updateTranslatedGlossaryAndHighlights()
                        }
                        .onChange(of: activeEditorState?.sourceAttributedText) {
                            // For source text (user typing), update highlights synchronously.
                            updateSourceGlossaryAndHighlights()
                        }
                        .onChange(of: activeEditorState?.translatedAttributedText) {
                            // For translated text:
                            // If actively streaming, dispatch highlight update asynchronously to avoid rapid double-updates.
                            // Otherwise (e.g., user manually editing translated text), update synchronously.
                            if translationViewModel.isTranslating {
                                DispatchQueue.main.async {
                                    updateTranslatedGlossaryAndHighlights()
                                }
                            } else {
                                updateTranslatedGlossaryAndHighlights()
                            }
                        }
                        .onChange(of: activeEditorState?.sourceSelection) { _, newSelection in
                            handleSourceGlossarySelection(newSelection)
                        }
            .onChange(of: activeEditorState?.translatedSelection) { _, newSelection in
                handleTranslatedGlossarySelection(newSelection)
            }
            .onChange(of: appContext.searchResultToHighlight) { _, newResult in
                if let result = newResult {
                    handleSearchResultNavigation(result)
                    // Clear the highlight request so it can be triggered again for the same item.
                    appContext.searchResultToHighlight = nil
                }
            }
            .onChange(of: searchViewModel.searchQuery) {
                updateEditorSearch()
            }
            .onChange(of: searchViewModel.currentResultIndex) {
                reapplySourceHighlights()
            }
            .onChange(of: projectManager.settings.disableGlossaryHighlighting) { _, _ in
                // Re-calculate and apply highlights when the setting is toggled to add/remove them instantly.
                updateSourceGlossaryAndHighlights()
                updateTranslatedGlossaryAndHighlights()
            }
            .sheet(isPresented: $isGlossaryExtractionPresented) {
                if let chapterID = activeChapter?.id {
                    GlossaryExtractionView(
                        project: project,
                        projectManager: projectManager,
                        currentChapterID: chapterID
                    )
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
    
    @ViewBuilder
    private func editorWithButtons(chapter: Chapter, editorState: ChapterEditorState) -> some View {
        ZStack {
            TranslationEditorView(
                sourceText: .init(get: { editorState.sourceAttributedText }, set: { editorState.sourceAttributedText = $0 }),
                translatedText: .init(get: { editorState.translatedAttributedText }, set: { editorState.translatedAttributedText = $0 }),
                sourceSelection: .init(get: { editorState.sourceSelection }, set: { editorState.sourceSelection = $0 }),
                translatedSelection: .init(get: { editorState.translatedSelection }, set: { editorState.translatedSelection = $0 }),
                projectManager: projectManager,
                chapter: chapter,
                isDisabled: translationViewModel.isTranslating
            )
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    configButton
                    extractGlossaryButton
                    promptPreviewButton(chapter: chapter)
                    translateButton(chapter: chapter)
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - Overlay Buttons
    
    private var configButton: some View {
        Button {
            isConfigPopoverShown.toggle()
        } label: {
            Label("Config", systemImage: "gearshape")
        }
        .tint(.gray)
        .buttonStyle(.borderedProminent)
        .popover(isPresented: $isConfigPopoverShown, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Force Line Count Sync", isOn: $project.translationConfig.forceLineCountSync)
                    .onChange(of: project.translationConfig.forceLineCountSync) { _, _ in
                        project.lastModifiedDate = Date()
                        projectManager.saveProject()
                    }
                
                Divider()
                
                HStack {
                    Toggle("Include previous chapter as context", isOn: $project.translationConfig.includePreviousContext)
                        .onChange(of: project.translationConfig.includePreviousContext) { _, _ in
                            project.lastModifiedDate = Date()
                            projectManager.saveProject()
                        }
                    Stepper(value: $project.translationConfig.previousContextChapterCount, in: 1...5) {
                        Text("\(project.translationConfig.previousContextChapterCount)")
                    }
                    .disabled(!project.translationConfig.includePreviousContext)
                    .onChange(of: project.translationConfig.previousContextChapterCount) { _, _ in
                        project.lastModifiedDate = Date()
                        projectManager.saveProject()
                    }
                }
            }
            .padding()
        }
        .help("Advanced translation settings")
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
    
    private var extractGlossaryButton: some View {
        Button {
            isGlossaryExtractionPresented.toggle()
        } label: {
            Label("Extract Glossary", systemImage: "wand.and.stars")
        }
        .tint(.gray)
        .buttonStyle(.borderedProminent)
        .help("Automatically extract potential new glossary terms from the source and translation text.")
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .disabled(isSourceTextEmpty || isTranslatedTextEmpty)
    }
    
    private func promptPreviewButton(chapter: Chapter) -> some View {
        Button("Prompt Preview", systemImage: "sparkles.square.filled.on.square", action: onShowPromptPreview)
            .tint(.gray)
            .buttonStyle(.borderedProminent)
            .help("Show the final prompt that will be sent to the AI")
            .disabled(isSourceTextEmpty)
            .onHover { isHovering in
                if isHovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
    }
    
    private func translateButton(chapter: Chapter) -> some View {
        Button("Translate", systemImage: "sparkles") {
            Task {
                await translationViewModel.streamTranslateChapter(project: project, chapter: chapter, settings: projectManager.settings, workspace: workspaceViewModel)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSourceTextEmpty || translationViewModel.isTranslating)
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
    // MARK: - Highlighting & Search Logic

    private func handleSearchResultNavigation(_ result: SearchResultItem) {
        // 1. Open the chapter if it's not already open and make it active.
        workspaceViewModel.openChapter(id: result.chapterID)
        
        // The view might need a moment to update after opening a new chapter.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let editorState = workspaceViewModel.editorStates[result.chapterID] else { return }
            
            // 2. Set the selection in the correct editor pane, which also scrolls to it.
            switch result.editorType {
            case .source:
                editorState.sourceSelection = result.absoluteMatchRange
            case .translated:
                editorState.translatedSelection = result.absoluteMatchRange
            }
        }
    }
    
    private func updateSourceGlossaryAndHighlights() {
        guard let state = activeEditorState else {
            self.glossaryMatches = []
            self.lastProcessedTextContent = nil
            return
        }

        let text = String(state.sourceAttributedText.characters)
        
        if text == lastProcessedTextContent {
            return
        }
        
        if projectManager.settings.disableGlossaryHighlighting {
            self.glossaryMatches = []
        } else {
            self.glossaryMatches = text.isEmpty ? [] : glossaryMatcher.detectTerms(in: text, from: project.glossaryEntries)
        }
        
        self.lastProcessedTextContent = text
        reapplySourceHighlights()
    }

    private func updateTranslatedGlossaryAndHighlights() {
        guard let state = activeEditorState else {
            self.translatedGlossaryMatches = []
            self.lastProcessedTranslatedTextContent = nil
            return
        }

        let text = String(state.translatedAttributedText.characters)

        if text == lastProcessedTranslatedTextContent {
            return
        }

        if projectManager.settings.disableGlossaryHighlighting {
            self.translatedGlossaryMatches = []
        } else {
            self.translatedGlossaryMatches = text.isEmpty ? [] : glossaryMatcher.detectTranslations(in: text, from: project.glossaryEntries)
        }
        
        self.lastProcessedTranslatedTextContent = text
        reapplyTranslatedHighlights()
    }

    private func reapplySourceHighlights() {
        guard let state = activeEditorState else { return }
        
        var attributedString = state.sourceAttributedText
        let fullRange = attributedString.startIndex..<attributedString.endIndex
        
        // 1. Clear all cosmetic attributes
        attributedString[fullRange].foregroundColor = NSColor.textColor
        attributedString[fullRange].underlineStyle = nil
        attributedString[fullRange].backgroundColor = nil

        // 2. Apply glossary highlights (conditionally)
        if !projectManager.settings.disableGlossaryHighlighting {
            for match in glossaryMatches {
                if let range = Range(match.range, in: attributedString) {
                    var container = AttributeContainer()
                    container.underlineStyle = .single
                    container.foregroundColor = NSColor(match.entry.category.highlightColor)
                    attributedString[range].mergeAttributes(container, mergePolicy: .keepNew)
                }
            }
        }
        
        // 3. Apply search highlights over glossary highlights
        for range in searchViewModel.searchResults {
            if let swiftRange = Range(range, in: attributedString) {
                attributedString[swiftRange].backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3)
            }
        }
        if let currentIndex = searchViewModel.currentResultIndex, currentIndex < searchViewModel.searchResults.count {
            let currentRange = searchViewModel.searchResults[currentIndex]
            if let swiftRange = Range(currentRange, in: attributedString) {
                attributedString[swiftRange].backgroundColor = NSColor.systemOrange.withAlphaComponent(0.5)
            }
        }
        
        state.sourceAttributedText = attributedString
    }
    
    private func reapplyTranslatedHighlights() {
        guard let state = activeEditorState else { return }
        
        var attributedString = state.translatedAttributedText
        let fullRange = attributedString.startIndex..<attributedString.endIndex
        
        // Clear all cosmetic attributes
        attributedString[fullRange].foregroundColor = NSColor.textColor
        attributedString[fullRange].underlineStyle = nil
        attributedString[fullRange].backgroundColor = nil

        // Apply glossary highlights
        if !projectManager.settings.disableGlossaryHighlighting {
            for match in translatedGlossaryMatches {
                if let range = Range(match.range, in: attributedString) {
                    var container = AttributeContainer()
                    container.underlineStyle = .single
                    container.foregroundColor = NSColor(match.entry.category.highlightColor)
                    attributedString[range].mergeAttributes(container, mergePolicy: .keepNew)
                }
            }
        }
        state.translatedAttributedText = attributedString
    }
    
    private func resetEditorSearch() {
        searchViewModel.searchQuery = ""
        isEditorSearchActive = false
        // The onChange on searchQuery will trigger updateEditorSearch() -> reapplySourceHighlights()
    }

    private func updateEditorSearch() {
        guard let state = activeEditorState else { return }
        // Use the explicit String initializer to get the content reliably.
        searchViewModel.updateSearch(in: String(state.sourceAttributedText.characters))
        reapplySourceHighlights()
        navigateToCurrentMatch()
    }
    
    private func findNextMatch() {
        searchViewModel.findNext()
    }

    private func findPreviousMatch() {
        searchViewModel.findPrevious()
    }
    
    private func navigateToCurrentMatch() {
        guard let state = activeEditorState,
              let index = searchViewModel.currentResultIndex,
              index < searchViewModel.searchResults.count else { return }
        
        let range = searchViewModel.searchResults[index]
        state.sourceSelection = range
    }
    
    private func handleSourceGlossarySelection(_ selection: NSRange?) {
        if projectManager.settings.disableGlossaryHighlighting { return }
        
        guard let state = activeEditorState,
              let selection = selection,
              selection.length == 0,
              !glossaryMatches.isEmpty else {
            if activeGlossaryInfo != nil { withAnimation { activeGlossaryInfo = nil } }
            return
        }
        
        let text = String(state.sourceAttributedText.characters)
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: text)) }) {
            withAnimation(.easeInOut) {
                activeGlossaryInfo = GlossaryInfo(entry: match.entry, isSourceTerm: true)
            }
        } else {
            if activeGlossaryInfo?.isSourceTerm == true {
                withAnimation { activeGlossaryInfo = nil }
            }
        }
    }

    private func handleTranslatedGlossarySelection(_ selection: NSRange?) {
        if projectManager.settings.disableGlossaryHighlighting { return }
        
        guard let state = activeEditorState,
              let selection = selection,
              selection.length == 0,
              !translatedGlossaryMatches.isEmpty else {
            if activeGlossaryInfo != nil { withAnimation { activeGlossaryInfo = nil } }
            return
        }
        
        let text = String(state.translatedAttributedText.characters)
        if let match = translatedGlossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: text)) }) {
            withAnimation(.easeInOut) {
                activeGlossaryInfo = GlossaryInfo(entry: match.entry, isSourceTerm: false)
            }
        } else {
            if activeGlossaryInfo?.isSourceTerm == false {
                withAnimation { activeGlossaryInfo = nil }
            }
        }
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

#Preview("Editor No Chapter") {
    let mocks = PreviewMocks.shared
    // Set active chapter to nil to see the placeholder
    mocks.workspaceViewModel.activeChapterID = nil
    
    return mocks.provide(to: EditorAreaView(
        project: mocks.project,
        translationViewModel: mocks.translationViewModel,
        onShowPromptPreview: {}
    ))
}
