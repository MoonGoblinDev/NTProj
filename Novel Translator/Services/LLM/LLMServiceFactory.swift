// FILE: Novel Translator/Services/LLM/LLMServiceFactory.swift
//
//  LLMServiceFactory.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

// The old LLMFactoryError is now replaced by the shared LLMServiceError.

class LLMServiceFactory {
    static func create(provider: APIConfiguration.APIProvider, config: APIConfiguration) throws -> LLMServiceProtocol {
        
        switch provider {
        case .google:
            guard let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
                throw LLMServiceError.apiKeyMissing(provider.displayName)
            }
            return GoogleService(apiKey: apiKey)
        case .openai:
            guard let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
                throw LLMServiceError.apiKeyMissing(provider.displayName)
            }
            return OpenAIService(apiKey: apiKey)
        case .anthropic:
            guard let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
                throw LLMServiceError.apiKeyMissing(provider.displayName)
            }
            return AnthropicService(apiKey: apiKey)
        case .deepseek:
            guard let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
                throw LLMServiceError.apiKeyMissing(provider.displayName)
            }
            return DeepseekService(apiKey: apiKey)
        case .ollama:
            guard let baseURL = config.baseURL, !baseURL.isEmpty else {
                throw LLMServiceError.invalidURL("Ollama base URL is missing or empty in configuration.")
            }
            return OllamaService(baseURL: baseURL)
        case .openrouter:
            return try OpenRouterService(config: config)
        case .custom:
            return try CustomOpenAIService(config: config)
        }
    }
}
