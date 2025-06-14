import SwiftUI

// The main container for all project data, conforming to ObservableObject for UI updates,
// and Codable for JSON persistence.
class TranslationProject: ObservableObject, Codable, Identifiable, Equatable { // FIX: Add Equatable conformance
    @Published var id: UUID
    @Published var name: String
    @Published var sourceLanguage: String
    @Published var targetLanguage: String
    @Published var createdDate: Date
    @Published var lastModifiedDate: Date
    @Published var projectDescription: String?
    
    @Published var selectedProvider: APIConfiguration.APIProvider?
    @Published var selectedModel: String
    @Published var selectedPromptPresetID: UUID?
    
    @Published var chapters: [Chapter]
    @Published var glossaryEntries: [GlossaryEntry]
    @Published var apiConfigurations: [APIConfiguration]
    @Published var promptPresets: [PromptPreset]
    
    // These are no longer direct relationships but part of the project file.
    @Published var stats: TranslationStats
    @Published var importSettings: ImportSettings

    init(name: String, sourceLanguage: String, targetLanguage: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdDate = Date()
        self.lastModifiedDate = Date()
        self.projectDescription = description

        self.selectedProvider = .google
        self.selectedModel = APIConfiguration.APIProvider.google.defaultModels.first ?? "gemini-1.5-flash-latest"
        self.selectedPromptPresetID = nil
        
        self.chapters = []
        self.glossaryEntries = []
        self.apiConfigurations = []
        self.promptPresets = []
        
        self.stats = TranslationStats()
        self.importSettings = ImportSettings()
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, name, sourceLanguage, targetLanguage, createdDate, lastModifiedDate, projectDescription
        case selectedProvider, selectedModel, selectedPromptPresetID
        case chapters, glossaryEntries, apiConfigurations, promptPresets, stats, importSettings
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModifiedDate = try container.decode(Date.self, forKey: .lastModifiedDate)
        projectDescription = try container.decodeIfPresent(String.self, forKey: .projectDescription)
        selectedProvider = try container.decodeIfPresent(APIConfiguration.APIProvider.self, forKey: .selectedProvider)
        selectedModel = try container.decode(String.self, forKey: .selectedModel)
        selectedPromptPresetID = try container.decodeIfPresent(UUID.self, forKey: .selectedPromptPresetID)
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        glossaryEntries = try container.decode([GlossaryEntry].self, forKey: .glossaryEntries)
        apiConfigurations = try container.decode([APIConfiguration].self, forKey: .apiConfigurations)
        promptPresets = try container.decode([PromptPreset].self, forKey: .promptPresets)
        stats = try container.decode(TranslationStats.self, forKey: .stats)
        importSettings = try container.decode(ImportSettings.self, forKey: .importSettings)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sourceLanguage, forKey: .sourceLanguage)
        try container.encode(targetLanguage, forKey: .targetLanguage)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModifiedDate, forKey: .lastModifiedDate)
        try container.encode(projectDescription, forKey: .projectDescription)
        try container.encode(selectedProvider, forKey: .selectedProvider)
        try container.encode(selectedModel, forKey: .selectedModel)
        try container.encode(selectedPromptPresetID, forKey: .selectedPromptPresetID)
        try container.encode(chapters, forKey: .chapters)
        try container.encode(glossaryEntries, forKey: .glossaryEntries)
        try container.encode(apiConfigurations, forKey: .apiConfigurations)
        try container.encode(promptPresets, forKey: .promptPresets)
        try container.encode(stats, forKey: .stats)
        try container.encode(importSettings, forKey: .importSettings)
    }

    // FIX: Add Equatable conformance by comparing unique IDs
    static func == (lhs: TranslationProject, rhs: TranslationProject) -> Bool {
        lhs.id == rhs.id
    }
}
