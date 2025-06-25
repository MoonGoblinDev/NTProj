//
//  DeepseekService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 18/06/25.
//

import Foundation
import Tiktoken

// MARK: - Codable Structs for API Communication (OpenAI-compatible)

// Request Payloads
private struct DeepseekRequestPayload: Codable {
    let model: String
    let messages: [DeepseekMessage]
    let temperature: Double?
    let max_tokens: Int?
    let stream: Bool
    let response_format: ResponseFormat?

    struct ResponseFormat: Codable {
        let type: String
    }
}

private struct DeepseekMessage: Codable {
    let role: String
    let content: String
}

// Non-Streaming Response Payload
private struct DeepseekResponsePayload: Codable {
    let id: String
    let choices: [DeepseekChoice]
    let usage: DeepseekUsage?
}

private struct DeepseekChoice: Codable {
    let message: DeepseekMessage
    let finish_reason: String?
}

private struct DeepseekUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
}

// Streaming Response Chunk Payload
private struct DeepseekStreamChunk: Codable {
    let id: String
    let choices: [DeepseekStreamChoice]
}

private struct DeepseekStreamChoice: Codable {
    let delta: DeepseekStreamDelta
    let finish_reason: String?
}

private struct DeepseekStreamDelta: Codable {
    let content: String?
}

// Model Listing Response
private struct DeepseekModelsListResponse: Codable {
    let data: [DeepseekModelInfo]
}

private struct DeepseekModelInfo: Codable {
    let id: String
    let owned_by: String
}


// MARK: - DeepseekService Implementation
class DeepseekService: LLMServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    private var headers: [String: String] {
        ["Authorization": "Bearer \(apiKey)"]
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Static Model Fetching
    static func fetchAvailableModels(apiKey: String?, baseURL: String? = nil) async throws -> [String] { // baseURL ignored
        guard let apiKey = apiKey, !apiKey.isEmpty else { return [] }
        
        let endpoint = "https://api.deepseek.com/v1/models"
        let headers = ["Authorization": "Bearer \(apiKey)"]
        
        let decodedResponse: DeepseekModelsListResponse = try await LLMServiceHelper.performGETRequest(urlString: endpoint, headers: headers)
        
        let filteredModels = decodedResponse.data
            .filter { $0.id.hasPrefix("deepseek-") }
            .map { $0.id }
            .sorted()
        
        return filteredModels
    }

    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        let urlString = "\(baseURL)/chat/completions"
        let payload = DeepseekRequestPayload(
            model: request.model,
            messages: [DeepseekMessage(role: "user", content: request.prompt)],
            temperature: request.configuration.temperature,
            max_tokens: request.configuration.maxTokens,
            stream: false,
            response_format: nil
        )

        let decodedResponse: DeepseekResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )

        guard let text = decodedResponse.choices.first?.message.content else {
            throw LLMServiceError.noResponseText
        }

        return TranslationResponse(
            translatedText: text,
            inputTokens: decodedResponse.usage?.prompt_tokens,
            outputTokens: decodedResponse.usage?.completion_tokens,
            modelUsed: request.model,
            finishReason: decodedResponse.choices.first?.finish_reason
        )
    }
    
    // MARK: - Streaming Translation
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlString = "\(baseURL)/chat/completions"
                    let payload = DeepseekRequestPayload(
                        model: request.model,
                        messages: [DeepseekMessage(role: "user", content: request.prompt)],
                        temperature: request.configuration.temperature,
                        max_tokens: request.configuration.maxTokens,
                        stream: true,
                        response_format: nil
                    )

                    let (bytes, _) = try await LLMServiceHelper.performStreamingRequest(
                        urlString: urlString,
                        payload: payload,
                        headers: headers
                    )
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6)
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            do {
                                let decodedChunk = try JSONDecoder().decode(DeepseekStreamChunk.self, from: jsonData)
                                let choice = decodedChunk.choices.first
                                
                                let chunk = StreamingTranslationChunk(
                                    textChunk: choice?.delta.content ?? "",
                                    inputTokens: nil,
                                    outputTokens: nil,
                                    finishReason: choice?.finish_reason
                                )
                                continuation.yield(chunk)

                                if chunk.isFinal {
                                    continuation.finish()
                                    return
                                }
                            } catch {
                                print("Deepseek stream decoding error on a chunk: \(error)")
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Glossary Extraction
    func extractGlossary(prompt: String) async throws -> [GlossaryEntry] {
        let urlString = "\(baseURL)/chat/completions"
        let payload = DeepseekRequestPayload(
            model: "deepseek-chat",
            messages: [DeepseekMessage(role: "user", content: prompt)],
            temperature: 0.1,
            max_tokens: nil,
            stream: false,
            response_format: .init(type: "json_object")
        )

        let decodedResponse: DeepseekResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )
        
        guard let jsonText = decodedResponse.choices.first?.message.content else {
            return []
        }
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMServiceError.responseDecodingFailed(URLError(.cannotDecodeContentData))
        }

        do {
            let wrapper = try JSONDecoder().decode(GlossaryResponseWrapper.self, from: jsonData)
            return wrapper.entries
        } catch {
            throw LLMServiceError.responseDecodingFailed(error)
        }
    }

    // MARK: - Token Counting
    func countTokens(text: String, model: String) async throws -> Int {
        do {
            let count = try await getTokenCount(for: text, model: "gpt-4")
            return count
        } catch {
            throw LLMServiceError.serviceNotImplemented("Token counting failed via Tiktoken: \(error.localizedDescription)")
        }
    }
}
