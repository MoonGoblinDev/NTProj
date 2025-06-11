//
//  APIConfiguration.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class APIConfiguration {
    @Attribute(.unique) var id: UUID
    var provider: APIProvider
    var apiKeyIdentifier: String
    var model: String
    var maxTokens: Int
    var temperature: Double
    var isDefault: Bool
    var createdDate: Date
    
    // Relationships
    var project: TranslationProject?
    
    enum APIProvider: String, CaseIterable, Codable {
        // For now, we only show Google as an option
        case google = "google"
        case openai = "openai"
        case anthropic = "anthropic"
        
        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .google: return "Google"
            }
        }
        
        var defaultModels: [String] {
            switch self {
            case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"]
            case .anthropic: return ["claude-3-5-sonnet-20240620", "claude-3-haiku-20240307"]
            case .google: return [] // This will now be fetched dynamically
            }
        }
    }
    
    init(provider: APIProvider, model: String) {
        self.id = UUID()
        self.provider = provider
        // The identifier will be based on the project's ID for uniqueness.
        self.apiKeyIdentifier = ""
        self.model = model
        self.maxTokens = 8192 // Gemini has a larger context window
        self.temperature = 0.3
        self.isDefault = false
        self.createdDate = Date()
    }
}
