// FILE: Novel Translator/Models/ViewModels/ChatViewModel.swift
//
// ChatViewModel.swift
// Novel Translator
//
// Created by Bregas Satria Wicaksono on 21/06/25.
//

import SwiftUI

@MainActor
@Observable
class ChatViewModel {
    // MARK: - Public State
    var messages: [ChatMessage] = []
    var currentConversationID: UUID?
    var currentInput: String = ""
    var isThinking: Bool = false
    var errorMessage: String?
    
    // State for managing chat mode and context
    var mode: ChatMode = .global
    var chatWindow: Window = .chat
    var focusContext: [UUID: ContextInclusion] = [:]
    
    // MARK: - Private Properties
    private let ragService = RAGService()
    private let projectManager: ProjectManager
    private let project: TranslationProject
    
    // MARK: - Enums for Mode and Context
    enum ChatMode: String, CaseIterable, Identifiable {
        case global = "Global"
        case focus = "Focus"
        var id: Self { self }
        
        var symbol: String {
            switch self {
            case .global:
                return "􀆪"
            case .focus:
                return "􀊫"
            }
        }
    }
    
    enum Window: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case archivedChat = "Archive"
        var id: Self { self }
        
        var symbol: String {
            switch self {
            case .chat:
                return "􀌪"
            case .archivedChat:
                return "􀈭"
            }
        }
    }
    
    enum ContextInclusion: String, CaseIterable, Identifiable {
        case source = "Raw"
        case translated = "Translation"
        case both = "Both"
        var id: Self { self }
    }
    
    // MARK: - Initializer
    init(projectManager: ProjectManager, project: TranslationProject, workspaceViewModel: WorkspaceViewModel) {
        self.projectManager = projectManager
        self.project = project
        
        self.messages.append(getWelcomeMessage())
        
        if let activeChapterID = workspaceViewModel.activeChapterID {
            self.focusContext[activeChapterID] = .both
        }
    }
    
    // MARK: - Computed Properties for UI
    var selectedFocusChapters: [Chapter] {
        project.chapters
            .filter { focusContext.keys.contains($0.id) }
            .sorted { $0.chapterNumber < $1.chapterNumber }
    }
    
    var unselectedFocusChapters: [Chapter] {
        project.chapters
            .filter { !focusContext.keys.contains($0.id) }
            .sorted { $0.chapterNumber < $1.chapterNumber }
    }
    
    var canArchiveOrReset: Bool {
        // Can archive or reset if there is more than just the initial welcome message.
        return messages.count > 1
    }
    
    // MARK: - Public Methods
    func sendMessage() {
        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        messages.append(.init(role: .user, content: trimmedInput, sources: nil))
        currentInput = ""
        isThinking = true
        errorMessage = nil
        
        Task {
            do {
                let (prompt, sources) = try generatePromptAndSources(for: trimmedInput)
                let response = try await performLLMRequest(with: prompt)
                
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: response.translatedText,
                    sources: sources.isEmpty ? nil : sources
                )
                messages.append(assistantMessage)
                
            } catch {
                let localizedError = error as? LocalizedError
                self.errorMessage = localizedError?.errorDescription ?? error.localizedDescription
                messages.append(.init(role: .assistant, content: "Sorry, I ran into an error: \(self.errorMessage!)", sources: nil))
            }
            
            isThinking = false
        }
    }
    
    func archiveCurrentChat() {
        guard canArchiveOrReset else { return }
        
        // If we are editing an existing archive, find it and update it.
        if let conversationID = currentConversationID,
           let index = project.archivedChats.firstIndex(where: { $0.id == conversationID }) {
            project.archivedChats[index].messages = messages
            project.archivedChats[index].lastModified = Date()
        } else {
            // Otherwise, create a new archive.
            let newArchive = ArchivedChatConversation(messages: messages)
            project.archivedChats.insert(newArchive, at: 0) // Prepend
        }
        
        // Save the project file
        project.lastModifiedDate = Date()
        projectManager.saveProject()
        
        // Reset the chat interface to the welcome screen
        resetChat()
    }
    
    func resetChat() {
        guard canArchiveOrReset else { return }
        messages = [getWelcomeMessage()]
        currentConversationID = nil // Reset the ID
    }
    
    func clearArchive() {
        project.archivedChats.removeAll()
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
    
    func loadConversation(_ conversation: ArchivedChatConversation) {
        self.messages = conversation.messages
        self.currentConversationID = conversation.id
        self.chatWindow = .chat // Switch view to the main chat interface
    }
    
    func deleteConversation(at offsets: IndexSet) {
        let sortedArchives = project.archivedChats.sorted { $0.lastModified > $1.lastModified }
        let idsToDelete = offsets.map { sortedArchives[$0].id }
        
        project.archivedChats.removeAll { idsToDelete.contains($0.id) }
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
    
    
    // MARK: - Private Helpers
    private func getWelcomeMessage() -> ChatMessage {
        .init(role: .assistant, content: "Hello! How can I help you with the content of '\(project.name)'?", sources: nil)
    }
    
    // MARK: - Private Prompt Generation
    private func generatePromptAndSources(for query: String) throws -> (prompt: String, sources: [String]) {
        switch mode {
        case .global:
            return generateGlobalPrompt(for: query)
        case .focus:
            return generateFocusPrompt(for: query)
        }
    }
    
    private func generateGlobalPrompt(for query: String) -> (prompt: String, sources: [String]) {
        let chunks = ragService.retrieveRelevantChunks(from: project, for: query)
        let prompt = ragService.generatePrompt(query: query, chunks: chunks)
        let sources = Set(chunks.map { "Ch. \($0.chapterNumber)" }).sorted()
        return (prompt, sources)
    }
    
    private func generateFocusPrompt(for query: String) -> (prompt: String, sources: [String]) {
        guard !focusContext.isEmpty else {
            let prompt = "You are a helpful assistant. The user has a question but has not provided any specific chapter context. Politely inform them to add chapters to the focus context to ask questions about them.\n\nUser's Question: \(query)\nAnswer:"
            return (prompt, [])
        }
        
        var contextString = ""
        var sourceTitles: [String] = []
        
        
        // Correctly sort the chapter UUIDs based on their corresponding chapter number.
        let sortedChapterIDs = focusContext.keys.sorted { uuid1, uuid2 in
            let chap1 = project.chapters.first(where: { $0.id == uuid1 })
            let chap2 = project.chapters.first(where: { $0.id == uuid2 })
            return (chap1?.chapterNumber ?? 0) < (chap2?.chapterNumber ?? 0)
        }
        
        for chapterID in sortedChapterIDs {
            guard let chapter = project.chapters.first(where: { $0.id == chapterID }),
                  let inclusionType = focusContext[chapterID] else { continue }
            
            sourceTitles.append("Ch. \(chapter.chapterNumber)")
            contextString += "\n\n--- CONTEXT FROM Chapter \(chapter.chapterNumber): \(chapter.title) ---\n"
            
            switch inclusionType {
            case .source:
                contextString += "[Source Text]:\n\(chapter.rawContent)"
            case .translated:
                contextString += "[Translated Text]:\n\(chapter.translatedContent ?? "Not translated.")"
            case .both:
                contextString += "[Source Text]:\n\(chapter.rawContent)\n\n[Translated Text]:\n\(chapter.translatedContent ?? "Not translated.")"
            }
        }
        
        let prompt = """
    You are a helpful assistant for a novel translator. Answer the user's question based *only* on the provided full text from the selected chapters. Quote from the text if it helps. If the context doesn't contain the answer, state that clearly.
    \(contextString)
    --- END OF ALL CONTEXT ---
    
    User's Question: \(query)
    
    Answer:
    """
        
        return (prompt, sourceTitles.sorted())
    }
    
    // MARK: - Private LLM Communication
    private func performLLMRequest(with prompt: String) async throws -> TranslationResponse {
        print("--- PROMPT SENT TO LLM ---")
        print(prompt)
        print("--- END OF PROMPT ---")
        
        guard let provider = projectManager.settings.selectedProvider else {
            throw LLMServiceError.serviceNotImplemented("No provider selected")
        }
        guard let config = projectManager.settings.apiConfigurations.first(where: { $0.provider == provider }) else {
            throw LLMServiceError.apiKeyMissing(provider.displayName)
        }
        let llmService = try LLMServiceFactory.create(provider: provider, config: config)
        
        let request = TranslationRequest(
            prompt: prompt,
            configuration: config,
            model: projectManager.settings.selectedModel
        )
        return try await llmService.translate(request: request)
    }
    
}
