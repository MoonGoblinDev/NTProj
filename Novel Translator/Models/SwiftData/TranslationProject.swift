//
//  TranslationProject.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class TranslationProject {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceLanguage: String
    var targetLanguage: String
    var createdDate: Date
    var lastModifiedDate: Date
    var projectDescription: String?
    
    // New: Store the currently selected provider and model for translation
    // FIX: Make the property optional to handle old data that doesn't have this field.
    var selectedProvider: APIConfiguration.APIProvider?
    var selectedModel: String = ""
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Chapter.project)
    var chapters: [Chapter] = []
    
    @Relationship(deleteRule: .cascade, inverse: \GlossaryEntry.project)
    var glossaryEntries: [GlossaryEntry] = []
    
    @Relationship(deleteRule: .cascade, inverse: \APIConfiguration.project)
    var apiConfigurations: [APIConfiguration] = []
    
    // Note: The summary mentions TranslationStats and ImportSettings as having a relationship,
    // but the provided model code uses a projectId. This implementation follows the model code.
    // If a direct relationship is desired, it should be added here.
    
    init(name: String, sourceLanguage: String, targetLanguage: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdDate = Date()
        self.lastModifiedDate = Date()
        self.projectDescription = description

        // Set a default model on creation for NEW projects.
        self.selectedProvider = .google
        self.selectedModel = APIConfiguration.APIProvider.google.defaultModels.first ?? "gemini-1.5-flash-latest"
    }
}
