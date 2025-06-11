import SwiftData
import Foundation

// MARK: - TranslationError Enum
enum TranslationError: LocalizedError {
    case projectNotFound
    case apiConfigMissing
    case llmServiceError(Error)
    case statsNotFound
    case factoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "The project for this chapter could not be found."
        case .apiConfigMissing:
            return "API configuration is missing for this project. Please set it up in Project Settings."
        case .llmServiceError(let underlyingError):
            return "An error occurred with the LLM service: \(underlyingError.localizedDescription)"
        case .statsNotFound:
            return "Could not find the statistics object for this project."
        case .factoryError(let error):
            return "Could not create LLM service: \(error.localizedDescription)"
        }
    }
}

// MARK: - TranslationService
@MainActor
class TranslationService {
    private var modelContext: ModelContext
    private let glossaryMatcher = GlossaryMatcher()
    private let promptBuilder = PromptBuilder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// This is the new primary method for saving the result of a completed stream.
    func saveStreamingResult(
        for chapter: Chapter,
        fullText: String,
        prompt: String,
        modelUsed: String,
        inputTokens: Int?,
        outputTokens: Int?,
        translationTime: TimeInterval
    ) throws {
        // 1. Get Project
        guard let project = chapter.project else {
            throw TranslationError.projectNotFound
        }

        // 2. Deactivate previous "current" version
        chapter.translationVersions.filter { $0.isCurrentVersion }.forEach { $0.isCurrentVersion = false }
        
        // 3. Create new version
        let newVersion = TranslationVersion(
            versionNumber: (chapter.translationVersions.map(\.versionNumber).max() ?? 0) + 1,
            content: fullText,
            llmModel: modelUsed,
            promptUsed: prompt,
            tokensUsed: (inputTokens ?? 0) + (outputTokens ?? 0),
            translationTime: translationTime,
            isCurrentVersion: true
        )
        newVersion.chapter = chapter
        modelContext.insert(newVersion)
        
        // 4. Update chapter with the final text
        chapter.translatedContent = fullText
        chapter.lastTranslatedDate = Date()
        chapter.translationStatus = .needsReview
        project.lastModifiedDate = Date()
        
        // 5. Update stats
        try updateStatsAfterTranslation(for: chapter, inputTokens: inputTokens, outputTokens: outputTokens, translationTime: translationTime)
        
        // 6. Update glossary usage
        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
        for match in matches {
            // Since `match.entry` is a reference to the model, we can modify it directly.
            match.entry.usageCount += 1
            match.entry.lastUsedDate = Date()
        }
        
        // 7. Save all changes to the database
        try modelContext.save()
    }
    
    /// Helper method to consolidate the logic for updating project statistics.
    private func updateStatsAfterTranslation(for chapter: Chapter, inputTokens: Int?, outputTokens: Int?, translationTime: TimeInterval) throws {
        guard let project = chapter.project else { return }
        let projectId = project.id
        let descriptor = FetchDescriptor<TranslationStats>(predicate: #Predicate { $0.projectId == projectId })
        
        guard let stats = try modelContext.fetch(descriptor).first else {
            throw TranslationError.statsNotFound
        }
        
        // Update general stats
        let tokensUsed = (inputTokens ?? 0) + (outputTokens ?? 0)
        stats.totalTokensUsed += tokensUsed
        
        // Update total chapter/word counts if new chapters were imported
        let currentTotalChapters = project.chapters.count
        if stats.totalChapters != currentTotalChapters {
            stats.totalChapters = currentTotalChapters
            stats.totalWords = project.chapters.reduce(0) { $0 + $1.wordCount }
        }
        
        let previouslyCompleted = Double(stats.completedChapters)
        
        // Increment completion counts only if this is the first translation for this chapter.
        // The new version was just added, so the count will be 1 if it was the first.
        if chapter.translationVersions.count == 1 {
            stats.completedChapters += 1
            stats.translatedWords += chapter.wordCount
        }
        
        // Recalculate average translation time
        if stats.completedChapters > 0 {
            let totalCompletedTime = (stats.averageTranslationTime * previouslyCompleted) + translationTime
            stats.averageTranslationTime = totalCompletedTime / Double(stats.completedChapters)
        } else {
            stats.averageTranslationTime = 0 // Should not happen if we just completed one, but safe to have.
        }
        
        stats.lastUpdated = Date()
        
        // TODO: Add real cost calculation logic based on model
        stats.estimatedCost += Double(tokensUsed) * 0.000002 // Placeholder cost (e.g., $2/1M tokens)
    }
    
    // NOTE: This original non-streaming method is kept for potential future use or for LLMs that don't support streaming.
    // It is not currently called by the UI.
    func translateChapter(_ chapter: Chapter) async throws {
        guard let project = chapter.project else { throw TranslationError.projectNotFound }
        guard let apiConfig = project.apiConfig else { throw TranslationError.apiConfigMissing }

        let startTime = Date()
        let matches = glossaryMatcher.detectTerms(in: chapter.rawContent, from: project.glossaryEntries)
        let prompt = promptBuilder.buildTranslationPrompt(
            text: chapter.rawContent,
            glossaryMatches: matches,
            sourceLanguage: project.sourceLanguage,
            targetLanguage: project.targetLanguage
        )

        let llmService: LLMServiceProtocol
        do {
            llmService = try LLMServiceFactory.create(provider: apiConfig.provider, config: apiConfig)
        } catch {
            throw TranslationError.factoryError(error)
        }
        
        let request = TranslationRequest(prompt: prompt, configuration: apiConfig)
        let response: TranslationResponse
        do {
            response = try await llmService.translate(request: request)
        } catch {
            throw TranslationError.llmServiceError(error)
        }
        
        let translationTime = Date().timeIntervalSince(startTime)

        // Call the save method with the final assembled data
        try saveStreamingResult(
            for: chapter,
            fullText: response.translatedText,
            prompt: prompt,
            modelUsed: response.modelUsed,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
            translationTime: translationTime
        )
    }
}
