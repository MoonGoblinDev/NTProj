import SwiftUI

@MainActor
@Observable
class GlossaryExtractionViewModel {
    
    // MARK: - State Management
    
    enum ViewState {
        case options
        case loading
        case results
        case error
    }
    var viewState: ViewState = .options
    
    // MARK: - Extraction Options
    
    var selectedChapterIDs: Set<UUID> = []
    let allCategories = GlossaryEntry.GlossaryCategory.allCases
    var selectedCategories: Set<GlossaryEntry.GlossaryCategory>
    var additionalQuery: String = ""
    var fillContext: Bool = true
    
    // MARK: - Results
    
    struct SelectableGlossaryEntry: Identifiable {
        let id = UUID()
        var entry: GlossaryEntry
        var isSelected: Bool = true
    }
    var selectableEntries: [SelectableGlossaryEntry] = []
    var errorMessage: String?
    
    // MARK: - Project Data
    
    let project: TranslationProject
    private let projectManager: ProjectManager
    
    // MARK: - Computed Properties for UI
    
    var selectedChapters: [Chapter] {
        project.chapters
            .filter { selectedChapterIDs.contains($0.id) }
            .sorted { $0.chapterNumber < $1.chapterNumber }
    }

    var unselectedChapters: [Chapter] {
        project.chapters
            .filter { !selectedChapterIDs.contains($0.id) }
            .sorted { $0.chapterNumber < $1.chapterNumber }
    }
    
    var selectedCategoryItems: [GlossaryEntry.GlossaryCategory] {
        allCategories.filter { selectedCategories.contains($0) }
    }

    var unselectedCategoryItems: [GlossaryEntry.GlossaryCategory] {
        allCategories.filter { !selectedCategories.contains($0) }
    }
    
    init(project: TranslationProject, projectManager: ProjectManager, currentChapterID: UUID) {
        self.project = project
        self.projectManager = projectManager
        // Default options
        self.selectedChapterIDs = [currentChapterID]
        self.selectedCategories = Set(GlossaryEntry.GlossaryCategory.allCases)
    }
    
    func startExtraction() {
        viewState = .loading
        errorMessage = nil
        
        // 1. Aggregate text from selected chapters
        var sourceText = ""
        var translatedText = ""
        let chaptersToProcess = project.chapters
            .filter { selectedChapterIDs.contains($0.id) }
            .sorted { $0.chapterNumber < $1.chapterNumber } // Process in order
        
        for chapter in chaptersToProcess {
            sourceText += chapter.rawContent + "\n\n"
            if let translated = chapter.translatedContent, !translated.isEmpty {
                translatedText += translated + "\n\n"
            }
        }
        
        // 2. Validate that there's text to process
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "The selected chapters do not have both source and translated text to analyze. Please ensure the selected chapters are translated first."
            self.viewState = .error
            return
        }
        
        // 3. Start the async task
        Task {
            let promptBuilder = PromptBuilder()
            let prompt = promptBuilder.buildGlossaryExtractionPrompt(
                sourceText: sourceText,
                translatedText: translatedText,
                existingGlossary: project.glossaryEntries,
                sourceLanguage: project.sourceLanguage,
                targetLanguage: project.targetLanguage,
                categoriesToExtract: Array(selectedCategories),
                additionalQuery: additionalQuery,
                fillContext: fillContext
            )
            
            do {
                guard let provider = projectManager.settings.selectedProvider else {
                    throw URLError(.userAuthenticationRequired)
                }
                guard let config = projectManager.settings.apiConfigurations.first(where: { $0.provider == provider }) else {
                     throw URLError(.userAuthenticationRequired)
                }
                let service = try LLMServiceFactory.create(provider: provider, config: config)
                let extracted = try await service.extractGlossary(prompt: prompt)
                
                // Filter out any duplicates that the AI might have returned anyway
                let existingOriginalTerms = Set(project.glossaryEntries.map { $0.originalTerm.lowercased() })
                let newEntries = extracted.filter { !existingOriginalTerms.contains($0.originalTerm.lowercased()) }

                self.selectableEntries = newEntries.map { SelectableGlossaryEntry(entry: $0) }
                self.viewState = .results

            } catch {
                let localizedError = error as? LocalizedError
                self.errorMessage = localizedError?.errorDescription ?? error.localizedDescription
                self.viewState = .error
            }
        }
    }
    
    func saveSelectedEntriesAndProject() {
        let entriesToAdd = selectableEntries.filter(\.isSelected).map(\.entry)
        guard !entriesToAdd.isEmpty else { return }
        
        project.glossaryEntries.append(contentsOf: entriesToAdd)
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
}
