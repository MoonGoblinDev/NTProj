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
    @State private var isEditorSearchActive = false
    @State private var isConfigPopoverShown = false
    @State private var isGlossaryExtractionPresented = false
    
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
                .sheet(isPresented: $isGlossaryExtractionPresented) {
                    if let chapterID = activeChapter?.id {
                        GlossaryExtractionView(
                            project: project,
                            projectManager: projectManager,
                            currentChapterID: chapterID
                        )
                    }
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
                // MODIFIED: Pass the workspaceViewModel to the updated function.
                await translationViewModel.streamTranslateChapter(project: project, chapter: chapter, settings: projectManager.settings, workspace: workspaceViewModel)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSourceTextEmpty || translationViewModel.isTranslating)
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
}
