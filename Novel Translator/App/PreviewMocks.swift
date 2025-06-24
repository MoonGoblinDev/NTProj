// FILE: Novel Translator/App/PreviewMocks.swift
//
//  PreviewMocks.swift
//  Novel Translator
//
//  Created for SwiftUI Previews
//

import SwiftUI

/// A centralized provider for all mock data needed for SwiftUI Previews.
/// This ensures consistency and simplifies preview setup.
///
/// Usage:
/// ```
/// #Preview {
///     let mocks = PreviewMocks.shared
///     return SomeView(project: mocks.project)
///         .environmentObject(mocks.projectManager)
///         // ... etc
/// }
/// ```
@MainActor
struct PreviewMocks {
    // MARK: - Singleton for easy access
    static let shared = PreviewMocks()

    // MARK: - Core Models
    let project: TranslationProject
    let chapter1: Chapter
    let chapter2: Chapter
    let chapter3: Chapter
    let glossaryEntry1: GlossaryEntry
    let glossaryEntry2: GlossaryEntry

    // MARK: - App State ViewModels
    let appContext: AppContext
    let projectManager: ProjectManager
    let workspaceViewModel: WorkspaceViewModel
    let translationViewModel: TranslationViewModel

    private init() {
        // --- Create Chapters ---
        var ch1 = Chapter(
            title: "The Beginning of the Tale",
            chapterNumber: 1,
            rawContent: """
            Once upon a time, in a land far, far away, lived a brave knight named Arthur.
            Arthur served the great Kingdom of Eldoria.

            He wielded the legendary sword, Excalibur, a gift from the Lady of the Lake.
            """
        )
        ch1.translatedContent = """
        昔々、遠い国に、アーサーという名の勇敢な騎士が住んでいました。
        アーサーは偉大なエルドリア王国に仕えていました。

        彼は湖の乙女からの贈り物である伝説の剣、エクスカリバーを振るった。
        """
        ch1.translationStatus = .completed
        ch1.translationVersions.append(TranslationVersion(versionNumber: 1, content: ch1.translatedContent!, llmModel: "gpt-4o"))

        var ch2 = Chapter(
            title: "The Dragon's Lair",
            chapterNumber: 2,
            rawContent: "The lair was dark and full of treasure. The dragon, Ignis, slept soundly on a pile of gold."
        )
        ch2.translationStatus = .pending

        var ch3 = Chapter(
            title: "A Glimmer of Hope",
            chapterNumber: 3,
            rawContent: "A single ray of light pierced the darkness of the cave."
        )
        ch3.translatedContent = ""
        ch3.translationStatus = .inProgress

        // ** THIS IS THE FIX **
        // Assign the temporary chapter variables to the struct's properties
        self.chapter1 = ch1
        self.chapter2 = ch2
        self.chapter3 = ch3

        // --- Create Glossary Entries ---
        self.glossaryEntry1 = GlossaryEntry(
            originalTerm: "Arthur",
            translation: "アーサー",
            category: .character,
            contextDescription: "The main protagonist, a brave knight.",
            aliases: ["Art"]
        )
        self.glossaryEntry2 = GlossaryEntry(
            originalTerm: "Eldoria",
            translation: "エルドリア",
            category: .place,
            contextDescription: "The kingdom Arthur serves."
        )
        let glossaryEntry3 = GlossaryEntry(
            originalTerm: "Excalibur",
            translation: "エクスカリバー",
            category: .object,
            contextDescription: "The legendary sword."
        )
        let glossaryEntry4 = GlossaryEntry(
            originalTerm: "Ignis",
            translation: "イグニス",
            category: .character,
            contextDescription: "A sleeping dragon."
        )

        // --- Create Archived Chats ---
        let chat1_msg1 = ChatMessage(role: .user, content: "What is Excalibur?", sources: nil, timestamp: Date().addingTimeInterval(-7200))
        let chat1_msg2 = ChatMessage(role: .assistant, content: "It is the legendary sword wielded by Arthur.", sources: ["Ch. 1"], timestamp: Date().addingTimeInterval(-7100))
        let archivedChat1 = ArchivedChatConversation(messages: [chat1_msg1, chat1_msg2], lastModified: Date().addingTimeInterval(-3600))

        let chat2_msg1 = ChatMessage(role: .user, content: "Tell me about Ignis the dragon.", sources: nil, timestamp: Date().addingTimeInterval(-8000))
        let chat2_msg2 = ChatMessage(role: .assistant, content: "Ignis is a dragon that sleeps on a pile of gold in a dark lair.", sources: ["Ch. 2"], timestamp: Date().addingTimeInterval(-7900))
        let archivedChat2 = ArchivedChatConversation(messages: [chat2_msg1, chat2_msg2], lastModified: Date().addingTimeInterval(-7200))

        // --- Create Translation Project ---
        let proj = TranslationProject(
            name: "The Knight's Tale",
            sourceLanguage: "English",
            targetLanguage: "Japanese"
        )
        proj.chapters = [self.chapter1, self.chapter2, self.chapter3]
        proj.glossaryEntries = [self.glossaryEntry1, self.glossaryEntry2, glossaryEntry3, glossaryEntry4]
        proj.archivedChats = [archivedChat1, archivedChat2]
        proj.stats.totalChapters = 3
        proj.stats.completedChapters = 1
        proj.stats.totalWords = 100
        proj.stats.translatedWords = 50
        proj.stats.totalTokensUsed = 12345
        proj.stats.estimatedCost = 0.0246
        proj.stats.averageTranslationTime = 15.7
        proj.importSettings.chapterSeparator = "\n---\n"
        proj.translationConfig.forceLineCountSync = false
        self.project = proj
        
        // --- Create App State Objects ---
        
        // AppContext
        self.appContext = AppContext()

        // ProjectManager
        let pm = ProjectManager()
        pm.setCurrentProjectForPreview(self.project)
        let projectMetadata = ProjectMetadata(id: self.project.id, name: self.project.name, bookmarkData: Data(), lastOpened: Date())
        let otherProjectMeta = ProjectMetadata(id: UUID(), name: "Another Story", bookmarkData: Data(), lastOpened: Date().addingTimeInterval(-86400))
        pm.settings.projects = [projectMetadata, otherProjectMeta]
        pm.settings.selectedProvider = .openai
        pm.settings.selectedModel = "gpt-4o"
        // Ensure OpenAI has an enabled model for the preview
        if let openAIConfigIndex = pm.settings.apiConfigurations.firstIndex(where: { $0.provider == .openai }) {
            pm.settings.apiConfigurations[openAIConfigIndex].enabledModels = ["gpt-4o", "gpt-3.5-turbo"]
        }
        if let presetID = pm.settings.promptPresets.first?.id {
            pm.settings.selectedPromptPresetID = presetID
        }
        self.projectManager = pm

        // WorkspaceViewModel
        let wvm = WorkspaceViewModel()
        wvm.setCurrentProject(self.project)
        // Simulate opening chapter 1 and 3
        wvm.openChapter(id: self.chapter1.id)
        wvm.openChapter(id: self.chapter3.id)
        wvm.activeChapterID = self.chapter1.id
        
        // Manually create an unsaved change in chapter 3's editor state
        if let ch3State = wvm.editorStates[self.chapter3.id] {
            var newText = ch3State.translatedAttributedText
            newText.characters.append(contentsOf: " (edited)")
            ch3State.translatedAttributedText = newText
        }
        self.workspaceViewModel = wvm

        // TranslationViewModel
        self.translationViewModel = TranslationViewModel()
    }

    /// A helper function to easily apply all standard environment objects to a view.
    func provide(to view: some View) -> some View {
        view
            .environmentObject(appContext)
            .environmentObject(projectManager)
            .environmentObject(workspaceViewModel)
    }
}
