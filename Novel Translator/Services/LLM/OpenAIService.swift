//
//  OpenAIService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

class OpenAIService: LLMServiceProtocol {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        // Placeholder: Implement actual API call to OpenAI
        print("Calling OpenAI API with model: \(request.configuration.model)")
        
        // Simulate network delay
        try await Task.sleep(for: .seconds(2))
        
        let simulatedResponse = "This is a simulated translation from OpenAI for the text."
        return TranslationResponse(
            translatedText: simulatedResponse,
            inputTokens: 100,
            outputTokens: 50,
            modelUsed: request.configuration.model,
            finishReason: "stop"
        )
    }
}
