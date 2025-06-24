//
//  ChatViewModel.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 21/06/25.
//

import SwiftUI

@MainActor
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var currentInput: String = ""
    var isThinking: Bool = false
    var errorMessage: String?
    
    private let ragService = RAGService()
    private let projectManager: ProjectManager
    private let project: TranslationProject
    
    init(projectManager: ProjectManager, project: TranslationProject) {
        self.projectManager = projectManager
        self.project = project
        
        // Add a welcome message
        self.messages.append(.init(role: .assistant, content: "Hello! How can I help you with the content of '\(project.name)'?", sources: nil))
    }
    
    func sendMessage() {
        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        // Add user message to the chat
        messages.append(.init(role: .user, content: trimmedInput, sources: nil))
        currentInput = ""
        isThinking = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Retrieve relevant context
                let chunks = ragService.retrieveRelevantChunks(from: project, for: trimmedInput)
                
                // 2. Build the prompt
                let prompt = ragService.generatePrompt(query: trimmedInput, chunks: chunks)
                
                print("--- RAG PROMPT SENT TO LLM ---")
                print(prompt)
                print("--- END OF RAG PROMPT ---")
                
                // 3. Get LLM Service
                guard let provider = projectManager.settings.selectedProvider else {
                    throw LLMServiceError.serviceNotImplemented("No provider selected")
                }
                guard let config = projectManager.settings.apiConfigurations.first(where: { $0.provider == provider }) else {
                    throw LLMServiceError.apiKeyMissing(provider.displayName)
                }
                let llmService = try LLMServiceFactory.create(provider: provider, config: config)
                
                // 4. Send request to LLM
                let request = TranslationRequest(
                    prompt: prompt,
                    configuration: config,
                    model: projectManager.settings.selectedModel
                )
                let response = try await llmService.translate(request: request)
                
                // 5. Create assistant message with sources
                let sources = Set(chunks.map { "Ch. \($0.chapterNumber)" }).sorted()
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
}
