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
    var apiKey: String // WARNING: Store securely, e.g., in Keychain
    var model: String
    var maxTokens: Int
    var temperature: Double
    var isDefault: Bool
    var createdDate: Date
    
    // Relationships
    var project: TranslationProject?
    
    enum APIProvider: String, CaseIterable, Codable {
        case openai = "openai"
        case anthropic = "anthropic"
        case google = "google"
        
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
            case .google: return ["gemini-1.5-pro-latest", "gemini-1.5-flash-latest"]
            }
        }
    }
    
    init(provider: APIProvider, apiKey: String, model: String) {
        self.id = UUID()
        self.provider = provider
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = 4096
        self.temperature = 0.3
        self.isDefault = false
        self.createdDate = Date()
    }
}
