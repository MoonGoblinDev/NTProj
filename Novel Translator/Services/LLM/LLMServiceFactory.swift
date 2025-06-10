//
//  LLMServiceFactory.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

class LLMServiceFactory {
    static func create(provider: APIConfiguration.APIProvider, config: APIConfiguration) -> LLMServiceProtocol {
        // In a real app, you would also pass the API key securely from Keychain.
        let apiKey = config.apiKey

        switch provider {
        case .openai:
            return OpenAIService(apiKey: apiKey)
        case .anthropic:
            return AnthropicService(apiKey: apiKey)
        case .google:
            return GoogleService(apiKey: apiKey)
        }
    }
}
