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
        
        guard let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
            throw LLMServiceError.apiKeyMissing(provider.displayName)
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
