// FILE: Novel Translator/Models/Data/TranslationProject.swift
import SwiftUI



class TranslationProject: ObservableObject, Codable, Identifiable, Equatable {
    @Published var id: UUID
    @Published var name: String
    @Published var sourceLanguage: String
    @Published var targetLanguage: String
    @Published var createdDate: Date
    @Published var lastModifiedDate: Date
    @Published var projectDescription: String?
    
    @Published var chapters: [Chapter]
    @Published var glossaryEntries: [GlossaryEntry]
    @Published var archivedChats: [ArchivedChatConversation] = []
    

    @Published var stats: TranslationStats
    @Published var importSettings: ImportSettings
    @Published var translationConfig: TranslationConfig

    struct TranslationConfig: Codable {
        var forceLineCountSync: Bool = false
        var includePreviousContext: Bool = false
        var previousContextChapterCount: Int = 1
        
        // Custom init for backward compatibility.
        // If an old project file is loaded, it won't have the new keys.
        // This prevents decoding from failing.
        enum CodingKeys: String, CodingKey {
            case forceLineCountSync, includePreviousContext, previousContextChapterCount
        }

        init() {} // Default initializer for new projects or missing config

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.forceLineCountSync = try container.decodeIfPresent(Bool.self, forKey: .forceLineCountSync) ?? false
            self.includePreviousContext = try container.decodeIfPresent(Bool.self, forKey: .includePreviousContext) ?? false
            self.previousContextChapterCount = try container.decodeIfPresent(Int.self, forKey: .previousContextChapterCount) ?? 1
        }
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
        self.archivedChats = []
        
        self.stats = TranslationStats()
        self.importSettings = ImportSettings()
        self.translationConfig = TranslationConfig()
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, name, sourceLanguage, targetLanguage, createdDate, lastModifiedDate, projectDescription
        case chapters, glossaryEntries, archivedChats, stats, importSettings, translationConfig
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
        archivedChats = try container.decodeIfPresent([ArchivedChatConversation].self, forKey: .archivedChats) ?? []
        stats = try container.decode(TranslationStats.self, forKey: .stats)
        importSettings = try container.decode(ImportSettings.self, forKey: .importSettings)
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
        try container.encode(archivedChats, forKey: .archivedChats)
        try container.encode(stats, forKey: .stats)
        try container.encode(importSettings, forKey: .importSettings)
        try container.encode(translationConfig, forKey: .translationConfig)
    }


    static func == (lhs: TranslationProject, rhs: TranslationProject) -> Bool {
        lhs.id == rhs.id
    }
}

/// A model for a single, archived chat conversation.
struct ArchivedChatConversation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var messages: [ChatMessage]
    var lastModified: Date = Date()
    
    /// A computed property to get a title for display in the archive list.
    var title: String {
        // Find the first user message to use as a title.
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let content = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? "Chat from \(lastModified.formatted(date: .abbreviated, time: .shortened))" : content
        }
        // Fallback title
        return "Chat from \(lastModified.formatted(date: .abbreviated, time: .shortened))"
    }
}
