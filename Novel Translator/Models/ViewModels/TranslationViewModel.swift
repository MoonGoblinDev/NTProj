// FILE: Novel Translator/Models/ViewModels/TranslationViewModel.swift

import SwiftUI

@Observable
@MainActor
class TranslationViewModel {
    var isTranslating: Bool = false
    var errorMessage: String?
    
    private var translationService: TranslationService
    
    init() {
        self.translationService = TranslationService()
    }
    
    func streamTranslateChapter(project: TranslationProject, chapter: Chapter, settings: AppSettings, workspace: WorkspaceViewModel) async {
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
        var accumulatedText = ""
        
        // Clear previous translation and explicitly set selection to start of document
        workspace.activeEditorState?.updateTranslation(newText: "")
        workspace.activeEditorState?.translatedSelection = NSRange(location: 0, length: 0)
        
        let startTime = Date()
        var finalInputTokens: Int?
        var finalOutputTokens: Int?
        
        let promptBuilder = PromptBuilder()
        let glossaryMatcher = GlossaryMatcher()
        
        let selectedPreset = settings.promptPresets.first { $0.id == settings.selectedPromptPresetID }
        
        var previousContextText: String? = nil
        if project.translationConfig.includePreviousContext {
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
                        .joined(separator: "\n\n---\n\n")
                }
            }
        }

        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
        let prompt = promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: project.sourceLanguage,
            targetLanguage: project.targetLanguage,
            preset: selectedPreset,
            config: project.translationConfig,
            previousContext: previousContextText
        )
        
        do {
            let llmService = try LLMServiceFactory.create(provider: apiConfig.provider, config: apiConfig)
            let request = TranslationRequest(prompt: prompt, configuration: apiConfig, model: settings.selectedModel)
            
            let stream = llmService.streamTranslate(request: request)
            
            for try await chunk in stream {
                accumulatedText += chunk.textChunk
                // Only update text content in ChapterEditorState. Do not change selection.
                workspace.activeEditorState?.updateTranslation(newText: accumulatedText)

                if chunk.isFinal {
                    finalInputTokens = chunk.inputTokens
                    finalOutputTokens = chunk.outputTokens
                }
            }
            
            var finalFullText = accumulatedText
            if project.translationConfig.forceLineCountSync {
                finalFullText = promptBuilder.postprocessLineSync(text: finalFullText)
                // Update the UI one last time with the cleaned text
                workspace.activeEditorState?.updateTranslation(newText: finalFullText)
            }

            // After stream is completely finished and text is final:
            // Explicitly set the selection in ChapterEditorState to the end of the final translated text.
            let finalLength = finalFullText.utf16.count
            workspace.activeEditorState?.translatedSelection = NSRange(location: finalLength, length: 0)

            // Once the stream is finished, save the final result to the in-memory model.
            let translationTime = Date().timeIntervalSince(startTime)
            translationService.updateModelsAfterStreaming(
                project: project,
                chapterID: chapter.id,
                fullText: finalFullText,
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
