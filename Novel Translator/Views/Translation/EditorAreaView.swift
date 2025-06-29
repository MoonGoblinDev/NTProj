// FILE: Novel Translator/Views/Translation/EditorAreaView.swift

import SwiftUI

struct EditorAreaView: View {
    // Environment
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    // Parent Models & State
    @ObservedObject var project: TranslationProject
    var translationViewModel: TranslationViewModel
    
    // Bindings from parent
    let onShowPromptPreview: () -> Void
    
    // New nested type for the glossary popup info, accessible to subviews.
    struct GlossaryInfo: Identifiable {
        let id = UUID()
        let entry: GlossaryEntry
        let isSourceTerm: Bool
    }
    
    private var activeChapter: Chapter? {
        workspaceViewModel.activeChapter
    }
    
    private var activeEditorState: ChapterEditorState? {
        workspaceViewModel.activeEditorState
    }

    var body: some View {
        // This is now a simple router. If a chapter is open, it shows the content view.
        // Otherwise, it shows a placeholder. This is easy for the compiler to type-check.
        if let chapter = activeChapter, let editorState = activeEditorState {
            EditorAreaContentView(
                project: project,
                chapter: chapter,
                editorState: editorState,
                translationViewModel: translationViewModel,
                onShowPromptPreview: onShowPromptPreview
            )
        } else {
            ContentUnavailableView("No Chapter Selected", systemImage: "text.book.closed", description: Text("Select a chapter from the list in the sidebar."))
        }
    }
}


// MARK: - Private Content View
/// This private view now contains the complex body and all its modifiers,
/// isolating the complexity from the parent view.
private struct EditorAreaContentView: View {
    // Environment
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var appContext: AppContext
    
    // Models passed from parent
    // *** THIS IS THE FIX: Changed from `let` to `@ObservedObject var` ***
    @ObservedObject var project: TranslationProject
    let chapter: Chapter
    let editorState: ChapterEditorState
    let translationViewModel: TranslationViewModel
    let onShowPromptPreview: () -> Void
    
    // State - all local state has been moved into this view
    @State private var glossaryMatches: [GlossaryMatch] = []
    @State private var translatedGlossaryMatches: [GlossaryMatch] = []
    @State private var lastProcessedTextContent: String?
    @State private var lastProcessedTranslatedTextContent: String?
    private let glossaryMatcher = GlossaryMatcher()
    
    @State private var searchViewModel = EditorSearchViewModel()
    @State private var isConfigPopoverShown = false
    @State private var isGlossaryAssistantPresented = false
    @State private var isHoveringOnTranslateButton = false
    
    // Alert state
    @State private var isOverwriteWarningPresented = false
    @State private var isNameVersionAlertPresented = false
    @State private var newVersionName = ""
    @State private var chapterForTranslation: Chapter?
    
    // Glossary popup state
    @State private var activeGlossaryInfo: EditorAreaView.GlossaryInfo?

    // Computed Properties
    private var isSourceTextEmpty: Bool { String(editorState.sourceAttributedText.characters).isEmpty }
    private var isTranslatedTextEmpty: Bool { String(editorState.translatedAttributedText.characters).isEmpty }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ChapterTabsView(workspaceViewModel: workspaceViewModel, project: project)
                editorWithButtons
            }
            
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
            updateSourceGlossaryAndHighlights()
            updateTranslatedGlossaryAndHighlights()
        }
        .onChange(of: chapter.id) {
            resetEditorSearch()
            lastProcessedTextContent = nil
            lastProcessedTranslatedTextContent = nil
            updateSourceGlossaryAndHighlights()
            updateTranslatedGlossaryAndHighlights()
        }
        .onChange(of: editorState.sourceAttributedText) { updateSourceGlossaryAndHighlights() }
        .onChange(of: editorState.translatedAttributedText) {
            if !translationViewModel.isTranslating {
                updateTranslatedGlossaryAndHighlights()
            }
        }
        .onChange(of: translationViewModel.isTranslating) { _, isTranslating in
            if !isTranslating {
                updateTranslatedGlossaryAndHighlights()
            }
        }
        .onChange(of: editorState.sourceSelection, perform: handleSourceGlossarySelection)
        .onChange(of: editorState.translatedSelection, perform: handleTranslatedGlossarySelection)
        .onChange(of: appContext.searchResultToHighlight) { _, newResult in
            if let result = newResult {
                handleSearchResultNavigation(result)
                appContext.searchResultToHighlight = nil
            }
        }
        .onChange(of: searchViewModel.searchQuery) { updateEditorSearch() }
        .onChange(of: searchViewModel.currentResultIndex) { reapplySourceHighlights() }
        .onChange(of: projectManager.settings.disableGlossaryHighlighting) { _, _ in
            updateSourceGlossaryAndHighlights()
            updateTranslatedGlossaryAndHighlights()
        }
        .sheet(isPresented: $isGlossaryAssistantPresented) {
            GlossaryAssistantView(project: project, projectManager: projectManager, currentChapterID: chapter.id)
        }
        .alert("Existing Translation Found", isPresented: $isOverwriteWarningPresented, presenting: chapterForTranslation) { ch in
            Button("Cancel", role: .cancel) { chapterForTranslation = nil }
            Button("Overwrite") {
                translationViewModel.streamTranslateChapter(project: project, chapter: ch, settings: projectManager.settings, workspace: workspaceViewModel)
                chapterForTranslation = nil
            }
            Button("Save Version & Translate") {
                newVersionName = "Snapshot - \(Date().formatted(date: .abbreviated, time: .shortened))"
                isNameVersionAlertPresented = true
            }
        } message: { _ in
            Text("This chapter already has a translation. How would you like to proceed?")
        }
        .alert("Save Current Translation as Version", isPresented: $isNameVersionAlertPresented) {
            TextField("Version Name", text: $newVersionName)
            Button("Cancel", role: .cancel) { chapterForTranslation = nil }
            Button("Save & Translate") {
                if let chapterToTranslate = chapterForTranslation {
                    let service = TranslationService()
                    service.createVersionSnapshot(project: project, chapterID: chapterToTranslate.id, name: newVersionName)
                    projectManager.saveProject()
                    translationViewModel.streamTranslateChapter(project: project, chapter: chapterToTranslate, settings: projectManager.settings, workspace: workspaceViewModel)
                }
                chapterForTranslation = nil
            }
        }
    }

    // MARK: - Subviews
    
    private var editorWithButtons: some View {
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
                    promptPreviewButton
                    translateButton
                }
                .padding(10)
            }
        }
    }
    
    private var configButton: some View {
        Button { isConfigPopoverShown.toggle() } label: { Label("Config", systemImage: "gearshape") }
        .tint(.gray).buttonStyle(.borderedProminent)
        .popover(isPresented: $isConfigPopoverShown, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Force Line Count Sync", isOn: $project.translationConfig.forceLineCountSync)
                    .onChange(of: project.translationConfig.forceLineCountSync) { _, _ in
                        project.lastModifiedDate = Date(); projectManager.saveProject()
                    }
                Divider()
                HStack {
                    Toggle("Include previous chapter as context", isOn: $project.translationConfig.includePreviousContext)
                        .onChange(of: project.translationConfig.includePreviousContext) { _, _ in
                            project.lastModifiedDate = Date(); projectManager.saveProject()
                        }
                    Stepper(value: $project.translationConfig.previousContextChapterCount, in: 1...5) {
                        Text("\(project.translationConfig.previousContextChapterCount)")
                    }
                    .disabled(!project.translationConfig.includePreviousContext)
                    .onChange(of: project.translationConfig.previousContextChapterCount) { _, _ in
                        project.lastModifiedDate = Date(); projectManager.saveProject()
                    }
                }
            }.padding()
        }
        .help("Advanced translation settings")
        .onHover { if $0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
    }
    
    private var extractGlossaryButton: some View {
        Button { isGlossaryAssistantPresented.toggle() } label: { Label("Glossary Assistant", systemImage: "wand.and.stars") }
        .tint(.gray).buttonStyle(.borderedProminent)
        .help("Extract or import glossary terms using AI.")
        .onHover { if $0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
        .disabled(isSourceTextEmpty || isTranslatedTextEmpty)
    }
    
    private var promptPreviewButton: some View {
        Button("Prompt Preview", systemImage: "sparkles.square.filled.on.square", action: onShowPromptPreview)
            .tint(.gray).buttonStyle(.borderedProminent)
            .help("Show the final prompt that will be sent to the AI")
            .disabled(isSourceTextEmpty)
            .onHover { if $0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
    }
    
    private var translateButton: some View {
        Button(action: {
            if translationViewModel.isTranslating {
                translationViewModel.cancelTranslation()
            } else {
                if let content = chapter.translatedContent, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.chapterForTranslation = chapter
                    isOverwriteWarningPresented = true
                } else {
                    translationViewModel.streamTranslateChapter(project: project, chapter: chapter, settings: projectManager.settings, workspace: workspaceViewModel)
                }
            }
        }) {
            if translationViewModel.isTranslating {
                if isHoveringOnTranslateButton { Label("Stop translating!", systemImage: "stop.fill") }
                else { HStack { ProgressView().frame(width: 10, height: 10).scaleEffect(0.4); Text("Translating...") } }
            } else { Label("Translate", systemImage: "sparkles") }
        }
        .buttonStyle(.borderedProminent)
        .tint(translationViewModel.isTranslating && isHoveringOnTranslateButton ? .red : .accentColor)
        .disabled(!translationViewModel.isTranslating && isSourceTextEmpty)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.1)) { self.isHoveringOnTranslateButton = isHovering }
            if (!translationViewModel.isTranslating && !isSourceTextEmpty) || translationViewModel.isTranslating { NSCursor.pointingHand.set() }
            else { NSCursor.arrow.set() }
        }
    }
    
    // MARK: - Logic Methods
    private func handleSearchResultNavigation(_ result: SearchResultItem) {
        workspaceViewModel.openChapter(id: result.chapterID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let editorState = workspaceViewModel.editorStates[result.chapterID] else { return }
            switch result.editorType {
            case .source: editorState.sourceSelection = result.absoluteMatchRange
            case .translated: editorState.translatedSelection = result.absoluteMatchRange
            }
        }
    }
    
    private func updateSourceGlossaryAndHighlights() {
        let text = String(editorState.sourceAttributedText.characters)
        if text == lastProcessedTextContent { return }
        
        self.glossaryMatches = projectManager.settings.disableGlossaryHighlighting ? [] : glossaryMatcher.detectTerms(in: text, from: project.glossaryEntries)
        self.lastProcessedTextContent = text
        reapplySourceHighlights()
    }

    private func updateTranslatedGlossaryAndHighlights() {
        let text = String(editorState.translatedAttributedText.characters)
        if text == lastProcessedTranslatedTextContent { return }
        
        self.translatedGlossaryMatches = projectManager.settings.disableGlossaryHighlighting ? [] : glossaryMatcher.detectTranslations(in: text, from: project.glossaryEntries)
        self.lastProcessedTranslatedTextContent = text
        reapplyTranslatedHighlights()
    }

    private func reapplySourceHighlights() {
        var attrString = editorState.sourceAttributedText
        let fullRange = attrString.startIndex..<attrString.endIndex
        
        attrString[fullRange].foregroundColor = NSColor.textColor
        attrString[fullRange].underlineStyle = nil
        attrString[fullRange].backgroundColor = nil

        if !projectManager.settings.disableGlossaryHighlighting {
            for match in glossaryMatches {
                if let range = Range(match.range, in: attrString) {
                    var container = AttributeContainer(); container.underlineStyle = .single; container.foregroundColor = NSColor(match.entry.category.highlightColor)
                    attrString[range].mergeAttributes(container, mergePolicy: .keepNew)
                }
            }
        }
        
        for range in searchViewModel.searchResults {
            if let swiftRange = Range(range, in: attrString) { attrString[swiftRange].backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3) }
        }
        if let idx = searchViewModel.currentResultIndex, idx < searchViewModel.searchResults.count {
            if let swiftRange = Range(searchViewModel.searchResults[idx], in: attrString) { attrString[swiftRange].backgroundColor = NSColor.systemOrange.withAlphaComponent(0.5) }
        }
        
        editorState.sourceAttributedText = attrString
    }
    
    private func reapplyTranslatedHighlights() {
        var attrString = editorState.translatedAttributedText
        let fullRange = attrString.startIndex..<attrString.endIndex
        
        attrString[fullRange].foregroundColor = NSColor.textColor; attrString[fullRange].underlineStyle = nil; attrString[fullRange].backgroundColor = nil

        if !projectManager.settings.disableGlossaryHighlighting {
            for match in translatedGlossaryMatches {
                if let range = Range(match.range, in: attrString) {
                    var container = AttributeContainer(); container.underlineStyle = .single; container.foregroundColor = NSColor(match.entry.category.highlightColor)
                    attrString[range].mergeAttributes(container, mergePolicy: .keepNew)
                }
            }
        }
        editorState.translatedAttributedText = attrString
    }
    
    private func resetEditorSearch() {
        searchViewModel.searchQuery = ""
    }

    private func updateEditorSearch() {
        searchViewModel.updateSearch(in: String(editorState.sourceAttributedText.characters))
        reapplySourceHighlights()
        navigateToCurrentMatch()
    }
    
    private func navigateToCurrentMatch() {
        guard let index = searchViewModel.currentResultIndex, index < searchViewModel.searchResults.count else { return }
        editorState.sourceSelection = searchViewModel.searchResults[index]
    }
    
    private func handleSourceGlossarySelection(_ selection: NSRange?) {
        if projectManager.settings.disableGlossaryHighlighting { return }
        guard let selection = selection, selection.length == 0, !glossaryMatches.isEmpty else {
            if activeGlossaryInfo != nil { withAnimation { activeGlossaryInfo = nil } }
            return
        }
        let text = String(editorState.sourceAttributedText.characters)
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: text)) }) {
            withAnimation(.easeInOut) { activeGlossaryInfo = EditorAreaView.GlossaryInfo(entry: match.entry, isSourceTerm: true) }
        } else {
            if activeGlossaryInfo?.isSourceTerm == true { withAnimation { activeGlossaryInfo = nil } }
        }
    }

    private func handleTranslatedGlossarySelection(_ selection: NSRange?) {
        if projectManager.settings.disableGlossaryHighlighting { return }
        guard let selection = selection, selection.length == 0, !translatedGlossaryMatches.isEmpty else {
            if activeGlossaryInfo != nil { withAnimation { activeGlossaryInfo = nil } }
            return
        }
        let text = String(editorState.translatedAttributedText.characters)
        if let match = translatedGlossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: text)) }) {
            withAnimation(.easeInOut) { activeGlossaryInfo = EditorAreaView.GlossaryInfo(entry: match.entry, isSourceTerm: false) }
        } else {
            if activeGlossaryInfo?.isSourceTerm == false { withAnimation { activeGlossaryInfo = nil } }
        }
    }
}
