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
    var maxTokens: Int
    var temperature: Double
    var enabledModels: [String] = [] // New: Models selected by user
    var createdDate: Date
    
    // Relationships
    var project: TranslationProject?
    
    enum APIProvider: String, CaseIterable, Codable, Identifiable {
        var id: String { self.rawValue }

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
            // Provide a default for project creation, even though it's fetched dynamically later.
            case .google: return ["gemini-1.5-flash-latest"]
            }
        }
    }
    
    init(provider: APIProvider) {
        self.id = UUID()
        self.provider = provider
        // The identifier will be based on the project's ID for uniqueness.
        self.apiKeyIdentifier = ""
        self.maxTokens = 8192 // Gemini has a larger context window
        self.temperature = 0.3
        self.enabledModels = []
        self.createdDate = Date()
    }
}
