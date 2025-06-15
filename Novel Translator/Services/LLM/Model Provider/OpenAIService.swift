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
        print("Calling OpenAI API with model: \(request.model)")
        
        // Simulate network delay
        try await Task.sleep(for: .seconds(2))
        
        let simulatedResponse = "This is a simulated translation from OpenAI for the text."
        return TranslationResponse(
            translatedText: simulatedResponse,
            inputTokens: 100,
            outputTokens: 50,
            modelUsed: request.model,
            finishReason: "stop"
        )
    }
}
