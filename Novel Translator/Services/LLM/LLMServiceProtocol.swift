//
//  LLMServiceProtocol.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

protocol LLMServiceProtocol {
    // Keep the original for non-streaming models in the future.
    func translate(request: TranslationRequest) async throws -> TranslationResponse
    
    // The new streaming method.
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error>
    
    // Method to get token count from the provider's API.
    func countTokens(text: String, model: String) async throws -> Int
    
    // Method to extract glossary terms from text, returning structured JSON.
    func extractGlossary(prompt: String) async throws -> [GlossaryEntry]
}

// Default implementation to make the new method optional for older services.
extension LLMServiceProtocol {
     func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMFactoryError.serviceNotImplemented("Streaming for this provider"))
        }
    }

    func countTokens(text: String, model: String) async throws -> Int {
        throw LLMFactoryError.serviceNotImplemented("Token counting for this provider")
    }
    
    func extractGlossary(prompt: String) async throws -> [GlossaryEntry] {
        throw LLMFactoryError.serviceNotImplemented("Glossary extraction for this provider")
    }
}
