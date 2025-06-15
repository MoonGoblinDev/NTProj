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
    
    @Published var chapters: [Chapter]
    @Published var glossaryEntries: [GlossaryEntry]
    
    // These are no longer direct relationships but part of the project file.
    @Published var stats: TranslationStats
    @Published var importSettings: ImportSettings
    @Published var translationConfig: TranslationConfig // NEW: Add translation config

    struct TranslationConfig: Codable {
        var forceLineCountSync: Bool = false
    }

    init(name: String, sourceLanguage: String, targetLanguage: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdDate = Date()
        self.lastModifiedDate = Date()
        self.projectDescription = description

        self.chapters = []
        self.glossaryEntries = []
        
        self.stats = TranslationStats()
        self.importSettings = ImportSettings()
        self.translationConfig = TranslationConfig() // NEW: Initialize config
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, name, sourceLanguage, targetLanguage, createdDate, lastModifiedDate, projectDescription
        case chapters, glossaryEntries, stats, importSettings, translationConfig // NEW: Add to coding keys
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
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        glossaryEntries = try container.decode([GlossaryEntry].self, forKey: .glossaryEntries)
        stats = try container.decode(TranslationStats.self, forKey: .stats)
        importSettings = try container.decode(ImportSettings.self, forKey: .importSettings)
        // NEW: Decode the config, providing a default for older project files that don't have it.
        translationConfig = try container.decodeIfPresent(TranslationConfig.self, forKey: .translationConfig) ?? TranslationConfig()
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
        try container.encode(chapters, forKey: .chapters)
        try container.encode(glossaryEntries, forKey: .glossaryEntries)
        try container.encode(stats, forKey: .stats)
        try container.encode(importSettings, forKey: .importSettings)
        try container.encode(translationConfig, forKey: .translationConfig) // NEW: Encode the config
    }

    // FIX: Add Equatable conformance by comparing unique IDs
    static func == (lhs: TranslationProject, rhs: TranslationProject) -> Bool {
        lhs.id == rhs.id
    }
}
