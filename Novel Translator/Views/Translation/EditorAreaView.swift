//
//  EditorAreaView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 16/06/25.
//

import SwiftUI

struct EditorAreaView: View {
    // Environment
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var appContext: AppContext
    
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
    
    // Local state for highlight management
    @State private var glossaryMatches: [GlossaryMatch] = []
    @State private var lastProcessedTextContent: String?
    private let glossaryMatcher = GlossaryMatcher()
    
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
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ChapterTabsView(workspaceViewModel: workspaceViewModel, project: project)
                    
                    editorWithButtons(chapter: chapter, editorState: editorState)
                }
            }
            .background(
                Button("") { isEditorSearchActive.toggle() }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            )
            .onAppear {
                // Initial load when the view appears for the first time
                updateGlossaryAndHighlights()
            }
            .onChange(of: activeChapter?.id) {
                // When chapter changes, force a full recalculation
                resetEditorSearch()
                lastProcessedTextContent = nil
                updateGlossaryAndHighlights()
            }
            .onChange(of: activeEditorState?.sourceAttributedText) {
                // When text is typed, trigger the controlled update asynchronously.
                // This breaks the update cycle that causes jittering.
                DispatchQueue.main.async {
                    updateGlossaryAndHighlights()
                }
            }
            .onChange(of: activeEditorState?.sourceSelection) { _, newSelection in
                handleGlossarySelection(newSelection)
            }
            .onChange(of: searchViewModel.searchQuery) {
                updateEditorSearch()
            }
            .onChange(of: searchViewModel.currentResultIndex) {
                reapplyAllHighlights()
            }
            .onChange(of: projectManager.settings.disableGlossaryHighlighting) { _, _ in
                // Re-calculate and apply highlights when the setting is toggled to add/remove them instantly.
                updateGlossaryAndHighlights()
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
                .padding()
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
                await translationViewModel.streamTranslateChapter(project: project, chapter: chapter, settings: projectManager.settings)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSourceTextEmpty || translationViewModel.isTranslating)
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }

    // MARK: - Highlighting & Search Logic
    
    /// The main driver for glossary matching and highlighting. This function is designed
    /// to be called only when the text content actually changes, preventing update loops.
    private func updateGlossaryAndHighlights() {
        guard let state = activeEditorState else {
            self.glossaryMatches = []
            self.lastProcessedTextContent = nil
            return
        }

        let text = String(state.sourceAttributedText.characters)
        
        if text == lastProcessedTextContent {
            return
        }
        
        // 1. Conditionally run the expensive glossary detection logic.
        if projectManager.settings.disableGlossaryHighlighting {
            // If disabled, ensure the matches array is empty.
            self.glossaryMatches = []
        } else {
            // If enabled, perform the detection.
            self.glossaryMatches = text.isEmpty ? [] : glossaryMatcher.detectTerms(in: text, from: project.glossaryEntries)
        }
        
        // 2. Store the content we just processed to use in the next check.
        self.lastProcessedTextContent = text
        
        // 3. Now that matches are updated (or cleared), re-apply all visual highlights.
        reapplyAllHighlights()
    }

    private func reapplyAllHighlights() {
        guard let state = activeEditorState else { return }
        
        var attributedString = state.sourceAttributedText
        let fullRange = attributedString.startIndex..<attributedString.endIndex
        
        // 1. Clear all cosmetic attributes
        attributedString[fullRange].foregroundColor = NSColor.textColor
        attributedString[fullRange].underlineStyle = nil
        attributedString[fullRange].backgroundColor = nil

        // 2. Apply glossary highlights (conditionally)
        
            for match in glossaryMatches {
                if let range = Range(match.range, in: attributedString) {
                    var container = AttributeContainer()
                    container.underlineStyle = .single
                    container.foregroundColor = NSColor(match.entry.category.highlightColor)
                    attributedString[range].mergeAttributes(container, mergePolicy: .keepNew)
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
    
    private func resetEditorSearch() {
        searchViewModel.searchQuery = ""
        isEditorSearchActive = false
        // The onChange on searchQuery will trigger updateEditorSearch() -> reapplyAllHighlights()
    }

    private func updateEditorSearch() {
        guard let state = activeEditorState else { return }
        // Use the explicit String initializer to get the content reliably.
        searchViewModel.updateSearch(in: String(state.sourceAttributedText.characters))
        reapplyAllHighlights()
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
    
    private func handleGlossarySelection(_ selection: NSRange?) {
        // Prevent selection logic from running if highlighting is off.
        if projectManager.settings.disableGlossaryHighlighting { return }
        
        guard let state = activeEditorState,
              let selection = selection,
              selection.length == 0,
              !glossaryMatches.isEmpty else { return }
        
        let text = String(state.sourceAttributedText.characters)
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: text)) }) {
            appContext.glossaryEntryToEditID = match.entry.id
        }
    }
}
