// FILE: Novel Translator/Services/LLM/Model Provider/CustomOpenAIService.swift
//
//  CustomOpenAIService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 24/06/25.
//

import Foundation
import Tiktoken

// Note: The DTOs (Data Transfer Objects) for this service are in the shared file:
// 'Novel Translator/Models/DTOs/OpenAICompatibleDTOs.swift'

class CustomOpenAIService: LLMServiceProtocol {
    private let config: APIConfiguration
    private let apiKey: String?
    private let baseURL: String

    private var headers: [String: String] {
        if let key = apiKey, !key.isEmpty {
            return ["Authorization": "Bearer \(key)"]
        }
        return [:]
    }

    init(config: APIConfiguration) throws {
        self.config = config
        self.apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) // Can be nil

        guard let baseURL = config.baseURL, !baseURL.isEmpty, let _ = URL(string: baseURL) else {
            throw LLMServiceError.invalidURL("Custom OpenAI-like base URL is missing or invalid.")
        }
        // Ensure base URL doesn't have a trailing slash for clean path appending.
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }
    
    static func fetchAvailableModels(apiKey: String?, baseURL: String?) async throws -> [String] {
        guard let baseURL = baseURL, !baseURL.isEmpty, let url = URL(string: baseURL) else {
            throw LLMServiceError.invalidURL("Base URL for fetching models is invalid.")
        }
        
        let endpoint = url.appendingPathComponent("v1/models").absoluteString
        var headers: [String: String] = [:]
        if let apiKey = apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        
        let decodedResponse: OpenAIModelsListResponse = try await LLMServiceHelper.performGETRequest(urlString: endpoint, headers: headers)
        
        let filteredModels = decodedResponse.data
            .filter { !$0.id.contains("vision") }
            .map { $0.id }
            .sorted()
            
        return filteredModels
    }

    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        let urlString = "\(baseURL)/v1/chat/completions"
        let payload = OpenAIRequestPayload(
            model: request.model,
            messages: [OpenAIMessage(role: "user", content: request.prompt)],
            temperature: request.configuration.temperature,
            max_tokens: request.configuration.maxTokens,
            stream: false,
            response_format: nil
        )

        let decodedResponse: OpenAIResponsePayload = try await LLMServiceHelper.performRequest(
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
    
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlString = "\(baseURL)/v1/chat/completions"
                    let payload = OpenAIRequestPayload(
                        model: request.model,
                        messages: [OpenAIMessage(role: "user", content: request.prompt)],
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
                            if jsonString == "[DONE]" { continuation.finish(); return }
                            
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }
                            let decodedChunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)
                            let choice = decodedChunk.choices.first
                            
                            let chunk = StreamingTranslationChunk(
                                textChunk: choice?.delta.content ?? "",
                                inputTokens: nil, outputTokens: nil, finishReason: choice?.finish_reason
                            )
                            continuation.yield(chunk)

                            if chunk.isFinal { continuation.finish(); return }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func extractGlossary(prompt: String, model: String) async throws -> [GlossaryEntry] {
        let urlString = "\(baseURL)/v1/chat/completions"
        let payload = OpenAIRequestPayload(
            model: model,
            messages: [OpenAIMessage(role: "user", content: prompt)],
            temperature: 0.1,
            max_tokens: nil,
            stream: false,
            response_format: .init(type: "json_object")
        )

        let decodedResponse: OpenAIResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )
        
        guard let jsonText = decodedResponse.choices.first?.message.content else { return [] }
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMServiceError.responseDecodingFailed(URLError(.cannotDecodeContentData))
        }

        let wrapper = try JSONDecoder().decode(GlossaryResponseWrapper.self, from: jsonData)
        return wrapper.entries
    }

    func countTokens(text: String, model: String) async throws -> Int {
        // Use Tiktoken with a generic model as the best-effort estimate.
        try await getTokenCount(for: text, model: "gpt-4")
    }
}
