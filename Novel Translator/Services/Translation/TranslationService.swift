import Foundation

// MARK: - TranslationError Enum
enum TranslationError: LocalizedError {
    case projectNotFound
    case chapterNotFound
    case apiConfigMissing
    case llmServiceError(Error)
    case factoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "The project could not be found."
        case .chapterNotFound:
            return "The chapter could not be found in the project."
        case .apiConfigMissing:
            return "API configuration is missing for this project. Please set it up in Project Settings."
        case .llmServiceError(let underlyingError):
            return "An error occurred with the LLM service: \(underlyingError.localizedDescription)"
        case .factoryError(let error):
            return "Could not create LLM service: \(error.localizedDescription)"
        }
    }
}

// MARK: - TranslationService
@MainActor
class TranslationService {
    private let glossaryMatcher = GlossaryMatcher()
    
    /// Creates a snapshot of the chapter's current translated state.
    func createVersionSnapshot(project: TranslationProject, chapterID: UUID, name: String) {
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapterID }),
              let translatedContent = project.chapters[chapterIndex].translatedContent,
              !translatedContent.isEmpty else {
            return
        }
        
        let chapter = project.chapters[chapterIndex]
        
        let newVersion = TranslationVersion(
            versionNumber: (chapter.translationVersions.map(\.versionNumber).max() ?? 0) + 1,
            content: translatedContent,
            llmModel: chapter.lastTranslationModel ?? "Manual Edit", // Use last model or "Manual"
            tokensUsed: chapter.lastTranslationTokensUsed,
            translationTime: chapter.lastTranslationTime,
            name: name.isEmpty ? nil : name // Use provided name
        )
        
        project.chapters[chapterIndex].translationVersions.append(newVersion)
        project.lastModifiedDate = Date()
        // The calling function will handle saving the project file.
    }

    /// Updates the in-memory models after a successful streaming translation.
    func updateModelsAfterStreaming(
        project: TranslationProject,
        chapterID: UUID,
        fullText: String,
        prompt: String,
        modelUsed: String,
        inputTokens: Int?,
        outputTokens: Int?,
        translationTime: TimeInterval
    ) {
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapterID }) else {
            print("Error: Could not find chapter with ID \(chapterID) to save result.")
            return
        }
        
        // 1. Update chapter with the final text and the new metadata properties
        project.chapters[chapterIndex].translatedContent = fullText
        project.chapters[chapterIndex].lastTranslatedDate = Date()
        project.chapters[chapterIndex].translationStatus = .needsReview
        project.chapters[chapterIndex].lastTranslationModel = modelUsed
        project.chapters[chapterIndex].lastTranslationTime = translationTime
        project.chapters[chapterIndex].lastTranslationTokensUsed = (inputTokens ?? 0) + (outputTokens ?? 0)
        
        project.lastModifiedDate = Date()
        
        // 2. Update stats
        updateStatsAfterTranslation(project: project, chapter: project.chapters[chapterIndex], inputTokens: inputTokens, outputTokens: outputTokens, translationTime: translationTime)
        
        // 3. Update glossary usage
        let matches = glossaryMatcher.detectTerms(in: project.chapters[chapterIndex].rawContent, from: project.glossaryEntries)
        for match in matches {
            if let entryIndex = project.glossaryEntries.firstIndex(where: { $0.id == match.entry.id }) {
                project.glossaryEntries[entryIndex].usageCount += 1
                project.glossaryEntries[entryIndex].lastUsedDate = Date()
            }
        }
    }
    
    /// Updates the in-memory chapter with manual edits from the UI.
    func updateChapterWithManualChanges(project: TranslationProject, chapterIndex: Int, rawContent: String, translatedContent: String) {
        var hasChanges = false
        var chapter = project.chapters[chapterIndex]
        
        // Update raw content if it changed
        if chapter.rawContent != rawContent {
            chapter.rawContent = rawContent
            hasChanges = true
        }

        // Update translated content if it changed
        if (chapter.translatedContent ?? "") != translatedContent {
            chapter.translatedContent = translatedContent
            
            hasChanges = true
        }

        if hasChanges {
            project.chapters[chapterIndex] = chapter
            project.lastModifiedDate = Date()
        }
    }
    
    private func updateStatsAfterTranslation(project: TranslationProject, chapter: Chapter, inputTokens: Int?, outputTokens: Int?, translationTime: TimeInterval) {
        // Update general stats
        let tokensUsed = (inputTokens ?? 0) + (outputTokens ?? 0)
        project.stats.totalTokensUsed += tokensUsed
        
        // Update total chapter/word counts if new chapters were imported
        let currentTotalChapters = project.chapters.count
        if project.stats.totalChapters != currentTotalChapters {
            project.stats.totalChapters = currentTotalChapters
            project.stats.totalWords = project.chapters.reduce(0) { $0 + $1.wordCount }
        }
        
        let previouslyCompleted = Double(project.stats.completedChapters)
        
        // Increment completion counts only if this is the first translation for this chapter.
        if chapter.lastTranslatedDate == nil { // A better check than versions.count
            project.stats.completedChapters += 1
            project.stats.translatedWords += chapter.wordCount
        }
        
        // Recalculate average translation time
        if project.stats.completedChapters > 0 {
            let totalCompletedTime = (project.stats.averageTranslationTime * previouslyCompleted) + translationTime
            project.stats.averageTranslationTime = totalCompletedTime / Double(project.stats.completedChapters)
        }
        
        project.stats.lastUpdated = Date()
        
        // TODO: Add real cost calculation logic based on model
        project.stats.estimatedCost += Double(tokensUsed) * 0.000002 // Placeholder cost
    }
}
