//
//  LLMServiceFactory.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

enum LLMFactoryError: LocalizedError {
    case apiKeyNotFound(String)
    case serviceNotImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotFound(let provider):
            return "API Key for \(provider) not found in Keychain. Please set it in Project Settings."
        case .serviceNotImplemented(let provider):
            return "The translation service for \(provider) is not yet implemented."
        }
    }
}

class LLMServiceFactory {
    static func create(provider: APIConfiguration.APIProvider, config: APIConfiguration) throws -> LLMServiceProtocol {
        
        guard let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) else {
            throw LLMFactoryError.apiKeyNotFound(provider.displayName)
        }

        switch provider {
        case .google:
            return GoogleService(apiKey: apiKey)
        case .openai:
            return OpenAIService(apiKey: apiKey)
        case .anthropic:
            return AnthropicService(apiKey: apiKey)
        case .deepseek:
            return DeepseekService(apiKey: apiKey)
        }
    }
}
