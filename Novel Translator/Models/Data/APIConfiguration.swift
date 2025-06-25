// FILE: Novel Translator/Models/Data/APIConfiguration.swift
import Foundation
import SwiftUI

struct APIConfiguration: Codable, Identifiable {
    var id: UUID = UUID()
    var provider: APIProvider
    var apiKeyIdentifier: String // For cloud services
    var baseURL: String? // For local services like Ollama
    var maxTokens: Int
    var temperature: Double
    var enabledModels: [String] = []
    var createdDate: Date = Date()
    
    enum APIProvider: String, CaseIterable, Codable, Identifiable {
        var id: String { self.rawValue }

        case google = "google"
        case openai = "openai"
        case anthropic = "anthropic"
        case deepseek = "deepseek"
        case ollama = "ollama" // New provider
        
        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .google: return "Google"
            case .deepseek: return "Deepseek"
            case .ollama: return "Ollama (Local)"
            }
        }
        
        var defaultModels: [String] {
            switch self {
            case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"]
            case .anthropic: return ["claude-3-5-sonnet-20240620", "claude-3-haiku-20240307"]
            case .google: return ["gemini-1.5-flash-latest"]
            case .deepseek: return ["deepseek-chat", "deepseek-coder"]
            case .ollama: return ["llama3", "mistral"] // Common default local models
            }
        }

        var logoName: String {
            switch self {
            case .google: "g.circle.fill"
            case .openai: "brain.head.profile"
            case .anthropic: "a.circle.fill"
            case .deepseek: "d.circle.fill"
            case .ollama: "shippingbox.fill" // Generic local/server icon
            }
        }

        var logoColor: Color {
            switch self {
            case .google: .blue
            case .openai: .green
            case .anthropic: .orange
            case .deepseek: .purple
            case .ollama: .gray
            }
        }
    }
    
    init(provider: APIProvider) {
        self.provider = provider
        self.apiKeyIdentifier = "" // Default, may not be used by all providers
        self.baseURL = provider == .ollama ? "http://localhost:11434" : nil // Default for Ollama
        self.maxTokens = 8192
        self.temperature = 0.3
        self.enabledModels = []
    }

    // Custom decoder to handle projects saved before `baseURL` was added.
    enum CodingKeys: String, CodingKey {
        case id, provider, apiKeyIdentifier, baseURL, maxTokens, temperature, enabledModels, createdDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        provider = try container.decode(APIProvider.self, forKey: .provider)
        apiKeyIdentifier = try container.decode(String.self, forKey: .apiKeyIdentifier)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL)
        maxTokens = try container.decode(Int.self, forKey: .maxTokens)
        temperature = try container.decode(Double.self, forKey: .temperature)
        enabledModels = try container.decode([String].self, forKey: .enabledModels)
        createdDate = try container.decode(Date.self, forKey: .createdDate)

        // Ensure baseURL is set for Ollama if it's missing (e.g. from older settings)
        if provider == .ollama && baseURL == nil {
            baseURL = "http://localhost:11434"
        }
    }
}
