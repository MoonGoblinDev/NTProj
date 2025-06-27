// FILE: Novel Translator/Models/Data/APIConfiguration.swift
import Foundation
import SwiftUI

struct APIConfiguration: Codable, Identifiable {
    var id: UUID = UUID()
    var provider: APIProvider
    var apiKeyIdentifier: String // For cloud services
    var baseURL: String? // For local/custom services
    var maxTokens: Int
    var temperature: Double
    var enabledModels: [String] = []
    var createdDate: Date = Date()
    
    // New fields for OpenRouter custom headers
    var openRouterSiteURL: String?
    var openRouterAppName: String?
    
    enum APIProvider: String, CaseIterable, Codable, Identifiable {
        var id: String { self.rawValue }

        case google = "google"
        case openai = "openai"
        case anthropic = "anthropic"
        case deepseek = "deepseek"
        case ollama = "ollama"
        case openrouter = "openrouter"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .google: return "Google"
            case .deepseek: return "Deepseek"
            case .ollama: return "Ollama (Local)"
            case .openrouter: return "OpenRouter"
            case .custom: return "Custom (OpenAI-like)"
            }
        }
        
        var defaultModels: [String] {
            switch self {
            case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"]
            case .anthropic: return ["claude-3-5-sonnet-20240620", "claude-3-haiku-20240307"]
            case .google: return ["gemini-1.5-flash-latest"]
            case .deepseek: return ["deepseek-chat", "deepseek-coder"]
            case .ollama: return ["llama3", "mistral"]
            case .openrouter: return ["openai/gpt-4o", "google/gemini-flash-1.5", "anthropic/claude-3-haiku-20240307", "mistralai/mistral-large-latest"]
            case .custom: return [] // User must fetch models from their custom endpoint
            }
        }

        var logoName: String {
            switch self {
            case .google: "g.circle.fill"
            case .openai: "brain.head.profile"
            case .anthropic: "a.circle.fill"
            case .deepseek: "d.circle.fill"
            case .ollama: "shippingbox.fill"
            case .openrouter: "arrow.triangle.swap"
            case .custom: "wrench.and.screwdriver.fill"
            }
        }

        var logoColor: Color {
            switch self {
            case .google: .blue
            case .openai: .green
            case .anthropic: .orange
            case .deepseek: .purple
            case .ollama: .gray
            case .openrouter: .blue
            case .custom: .cyan
            }
        }
    }
    
    init(provider: APIProvider) {
        self.provider = provider
        self.apiKeyIdentifier = ""
        self.baseURL = provider == .ollama ? "http://localhost:11434" : nil
        self.maxTokens = 8192
        self.temperature = 0.3
        self.enabledModels = []
        self.openRouterSiteURL = nil
        self.openRouterAppName = nil
    }

    // Custom decoder to handle projects saved before new fields were added.
    enum CodingKeys: String, CodingKey {
        case id, provider, apiKeyIdentifier, baseURL, maxTokens, temperature, enabledModels, createdDate, openRouterSiteURL, openRouterAppName
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
        openRouterSiteURL = try container.decodeIfPresent(String.self, forKey: .openRouterSiteURL)
        openRouterAppName = try container.decodeIfPresent(String.self, forKey: .openRouterAppName)

        // Ensure baseURL is set for Ollama if it's missing (e.g. from older settings)
        if provider == .ollama && baseURL == nil {
            baseURL = "http://localhost:11434"
        }
    }
}
