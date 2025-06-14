import SwiftUI

@Observable
@MainActor
class TranslationViewModel {
    var isTranslating: Bool = false
    var errorMessage: String?
    
    // This property will be bound to the TextEditor for live updates.
    var translationText: String = ""
    
    private var translationService: TranslationService
    
    init() {
        self.translationService = TranslationService()
    }
    
    // Sets the initial text in the editor when a chapter is selected.
    func setChapter(_ chapter: Chapter?) {
        // Don't overwrite text if a translation is in progress
        guard !isTranslating else { return }
        self.translationText = chapter?.translatedContent ?? ""
    }
    
    func streamTranslateChapter(project: TranslationProject, chapter: Chapter) async {
        // FIX: Safely unwrap the optional provider, defaulting to .google if it's nil.
        let activeProvider = project.selectedProvider ?? .google
        
        guard let apiConfig = project.apiConfigurations.first(where: { $0.provider == activeProvider }) else {
            errorMessage = "API configuration for \(activeProvider.displayName) not found."
            return
        }

        guard !project.selectedModel.isEmpty else {
            errorMessage = "No translation model selected. Please choose one from the toolbar."
            return
        }
        
        isTranslating = true
        errorMessage = nil
        translationText = "" // Clear previous translation
        
        let startTime = Date()
        var finalInputTokens: Int?
        var finalOutputTokens: Int?
        
        let promptBuilder = PromptBuilder()
        let glossaryMatcher = GlossaryMatcher()
        
        // NEW: Fetch the selected preset
        let selectedPreset = project.promptPresets.first { $0.id == project.selectedPromptPresetID }
        
        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
        let prompt = promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: project.sourceLanguage,
            targetLanguage: project.targetLanguage,
            preset: selectedPreset // Pass the preset to the builder
        )
        
        do {
            let llmService = try LLMServiceFactory.create(provider: apiConfig.provider, config: apiConfig)
            let request = TranslationRequest(prompt: prompt, configuration: apiConfig, model: project.selectedModel)
            
            let stream = llmService.streamTranslate(request: request)
            
            for try await chunk in stream {
                translationText += chunk.textChunk
                if chunk.isFinal {
                    finalInputTokens = chunk.inputTokens
                    finalOutputTokens = chunk.outputTokens
                }
            }
            
            // Once the stream is finished, save the final result to the in-memory model.
            let translationTime = Date().timeIntervalSince(startTime)
            translationService.updateModelsAfterStreaming(
                project: project,
                chapterID: chapter.id,
                fullText: translationText,
                prompt: prompt,
                modelUsed: project.selectedModel,
                inputTokens: finalInputTokens,
                outputTokens: finalOutputTokens,
                translationTime: translationTime
            )
            
        } catch {
            let localizedError = error as? LocalizedError
            errorMessage = "Translation failed: \(localizedError?.errorDescription ?? error.localizedDescription)"
        }
        
        isTranslating = false
    }
}
