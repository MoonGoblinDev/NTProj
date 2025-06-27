import SwiftUI

@MainActor
@Observable
class GlossaryAssistantViewModel {
    
    // MARK: - State Management
    enum ViewState {
        case initial, options, loading, results, error
    }
    enum Mode {
        case extract, importJSON, importText
    }
    var viewState: ViewState = .initial
    var mode: Mode = .extract
    
    // MARK: - Options
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
    
    init(project: TranslationProject, projectManager: ProjectManager, currentChapterID: UUID?) {
        self.project = project
        self.projectManager = projectManager
        // Default options
        if let id = currentChapterID {
            self.selectedChapterIDs = [id]
        }
        self.selectedCategories = Set(GlossaryEntry.GlossaryCategory.allCases)
    }
    
    func setModeAndProceed(_ newMode: Mode) {
        self.mode = newMode
        switch newMode {
        case .extract:
            self.viewState = .options
        case .importJSON, .importText:
            Task { await processImport() }
        }
    }
    
    func startExtraction() {
        viewState = .loading
        errorMessage = nil
        
        var sourceText = ""
        var translatedText = ""
        let chaptersToProcess = project.chapters
            .filter { selectedChapterIDs.contains($0.id) }
            .sorted { $0.chapterNumber < $1.chapterNumber }
        
        for chapter in chaptersToProcess {
            sourceText += chapter.rawContent + "\n\n"
            if let translated = chapter.translatedContent, !translated.isEmpty {
                translatedText += translated + "\n\n"
            }
        }
        
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "The selected chapters do not have both source and translated text to analyze."
            self.viewState = .error
            return
        }
        
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
            
            await performGlossaryRequest(prompt: prompt)
        }
    }
    
    private func processImport() async {
        viewState = .loading
        errorMessage = nil
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = (mode == .importJSON) ? [.json] : [.plainText]
        
        guard openPanel.runModal() == .OK, let url = openPanel.url else {
            viewState = .initial // User cancelled
            return
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            
            if mode == .importJSON {
                guard let data = content.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
                let wrapper = try JSONDecoder().decode(GlossaryResponseWrapper.self, from: data)
                processResults(wrapper.entries)
            } else { // mode == .importText
                let promptBuilder = PromptBuilder()
                let prompt = promptBuilder.buildGlossaryImportFromTextPrompt(
                    text: content,
                    sourceLanguage: project.sourceLanguage,
                    targetLanguage: project.targetLanguage
                )
                await performGlossaryRequest(prompt: prompt)
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.viewState = .error
        }
    }
    
    private func performGlossaryRequest(prompt: String) async {
        do {
            guard let provider = projectManager.settings.selectedProvider,
                  let config = projectManager.settings.apiConfigurations.first(where: { $0.provider == provider }) else {
                throw LLMServiceError.serviceNotImplemented("No provider configured for this operation.")
            }
            let service = try LLMServiceFactory.create(provider: provider, config: config)
            let extractedEntries = try await service.extractGlossary(prompt: prompt)
            processResults(extractedEntries)
        } catch {
            let localizedError = error as? LocalizedError
            self.errorMessage = localizedError?.errorDescription ?? error.localizedDescription
            self.viewState = .error
        }
    }
    
    private func processResults(_ entries: [GlossaryEntry]) {
        let existingOriginalTerms = Set(project.glossaryEntries.map { $0.originalTerm.lowercased() })
        let newEntries = entries.filter { !existingOriginalTerms.contains($0.originalTerm.lowercased()) }

        self.selectableEntries = newEntries.map { SelectableGlossaryEntry(entry: $0) }
        self.viewState = .results
    }
    
    func saveSelectedEntriesAndProject() {
        let entriesToAdd = selectableEntries.filter(\.isSelected).map(\.entry)
        guard !entriesToAdd.isEmpty else { return }
        
        project.glossaryEntries.append(contentsOf: entriesToAdd)
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
}
