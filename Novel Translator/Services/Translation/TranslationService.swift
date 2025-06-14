import SwiftData
import Foundation

// MARK: - TranslationError Enum
enum TranslationError: LocalizedError {
    case projectNotFound
    case apiConfigMissing
    case llmServiceError(Error)
    case statsNotFound
    case factoryError(Error)
    case noCurrentVersion
    
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
        case .noCurrentVersion:
            return "Could not find a current version to save changes to."
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
            match.entry.usageCount += 1
            match.entry.lastUsedDate = Date()
        }
        
        // 7. Save all changes to the database
        try modelContext.save()
    }
    
    /// **NEW:** A dedicated function for saving manual edits from the UI.
    func saveManualChanges(for chapter: Chapter, rawContent: String, translatedContent: String) throws {
        var hasChanges = false
        
        // Update raw content if it changed
        if chapter.rawContent != rawContent {
            chapter.rawContent = rawContent
            hasChanges = true
        }

        // Update translated content if it changed
        if (chapter.translatedContent ?? "") != translatedContent {
            chapter.translatedContent = translatedContent
            
            // Also update the content of the "current" translation version
            if let currentVersion = chapter.translationVersions.first(where: { $0.isCurrentVersion }) {
                currentVersion.content = translatedContent
            } else if !translatedContent.isEmpty {
                // If there's no version history yet, create the first one.
                let newVersion = TranslationVersion(versionNumber: 1, content: translatedContent, llmModel: "Manual Edit")
                newVersion.chapter = chapter
                modelContext.insert(newVersion)
            }
            hasChanges = true
        }

        // Only save if there were actual changes
        if hasChanges {
            chapter.project?.lastModifiedDate = Date()
            print("Saving manual changes...")
            try modelContext.save()
            print("Manual changes saved successfully.")
        }
    }
    
    /// **MODIFIED:** Helper method to consolidate the logic for updating project statistics.
    /// This is now robust and will create a stats object if one doesn't exist.
    private func updateStatsAfterTranslation(for chapter: Chapter, inputTokens: Int?, outputTokens: Int?, translationTime: TimeInterval) throws {
        guard let project = chapter.project else { return }
        let projectId = project.id
        let descriptor = FetchDescriptor<TranslationStats>(predicate: #Predicate { $0.projectId == projectId })
        
        // Try to fetch stats, but if it fails, create a new one.
        let stats: TranslationStats
        if let existingStats = try modelContext.fetch(descriptor).first {
            stats = existingStats
        } else {
            print("Warning: TranslationStats not found for project \(project.name). Creating a new one.")
            let newStats = TranslationStats(projectId: projectId)
            modelContext.insert(newStats)
            stats = newStats
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
        if chapter.translationVersions.count == 1 {
            stats.completedChapters += 1
            stats.translatedWords += chapter.wordCount
        }
        
        // Recalculate average translation time
        if stats.completedChapters > 0 {
            let totalCompletedTime = (stats.averageTranslationTime * previouslyCompleted) + translationTime
            stats.averageTranslationTime = totalCompletedTime / Double(stats.completedChapters)
        }
        
        stats.lastUpdated = Date()
        
        // TODO: Add real cost calculation logic based on model
        stats.estimatedCost += Double(tokensUsed) * 0.000002 // Placeholder cost
    }
    
    // NOTE: This original non-streaming method is kept for potential future use.
    func translateChapter(_ chapter: Chapter) async throws {
        guard let project = chapter.project else { throw TranslationError.projectNotFound }
        guard let apiConfig = project.apiConfigurations.first(where: { $0.provider == project.selectedProvider }) else { throw TranslationError.apiConfigMissing }
        guard !project.selectedModel.isEmpty else { throw TranslationError.apiConfigMissing }


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
        
        let request = TranslationRequest(prompt: prompt, configuration: apiConfig, model: project.selectedModel)
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
