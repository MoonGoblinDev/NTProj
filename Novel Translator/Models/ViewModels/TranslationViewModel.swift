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
    
    func streamTranslateChapter(project: TranslationProject, chapter: Chapter, settings: AppSettings) async {
        let activeProvider = settings.selectedProvider ?? .google
        
        guard let apiConfig = settings.apiConfigurations.first(where: { $0.provider == activeProvider }) else {
            errorMessage = "API configuration for \(activeProvider.displayName) not found."
            return
        }

        guard !settings.selectedModel.isEmpty else {
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
        
        let selectedPreset = settings.promptPresets.first { $0.id == settings.selectedPromptPresetID }
        
        // --- NEW: Context gathering logic ---
        var previousContextText: String? = nil
        if project.translationConfig.includePreviousContext {
            // Sort chapters to be sure of order
            let sortedChapters = project.chapters.sorted { $0.chapterNumber < $1.chapterNumber }
            if let currentChapterIndex = sortedChapters.firstIndex(where: { $0.id == chapter.id }) {
                let count = project.translationConfig.previousContextChapterCount
                let startIndex = max(0, currentChapterIndex - count)
                let endIndex = currentChapterIndex
                
                if startIndex < endIndex {
                    let contextChapters = sortedChapters[startIndex..<endIndex]
                    previousContextText = contextChapters
                        .compactMap { $0.translatedContent }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n\n---\n\n") // Separator between chapters
                }
            }
        }
        // --- END NEW ---

        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
        // UPDATED: Pass the project's translationConfig to the builder
        let prompt = promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: project.sourceLanguage,
            targetLanguage: project.targetLanguage,
            preset: selectedPreset,
            config: project.translationConfig, // Pass the new config
            previousContext: previousContextText
        )
        
        do {
            let llmService = try LLMServiceFactory.create(provider: apiConfig.provider, config: apiConfig)
            let request = TranslationRequest(prompt: prompt, configuration: apiConfig, model: settings.selectedModel)
            
            let stream = llmService.streamTranslate(request: request)
            
            for try await chunk in stream {
                translationText += chunk.textChunk
                if chunk.isFinal {
                    finalInputTokens = chunk.inputTokens
                    finalOutputTokens = chunk.outputTokens
                }
            }
            
            // --- NEW: Post-processing step ---
            var finalFullText = translationText
            if project.translationConfig.forceLineCountSync {
                finalFullText = promptBuilder.postprocessLineSync(text: finalFullText)
                // Update the UI one last time with the cleaned text
                translationText = finalFullText
            }

            // Once the stream is finished, save the final result to the in-memory model.
            let translationTime = Date().timeIntervalSince(startTime)
            translationService.updateModelsAfterStreaming(
                project: project,
                chapterID: chapter.id,
                fullText: finalFullText, // Use the potentially cleaned text
                prompt: prompt,
                modelUsed: settings.selectedModel,
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
