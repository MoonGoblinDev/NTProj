//
//  AnthropicService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

// MARK: - Codable Structs for API Communication

// Request Payloads
private struct AnthropicRequestPayload: Codable {
    let model: String
    let messages: [AnthropicMessage]
    let max_tokens: Int
    let temperature: Double?
    let stream: Bool
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

// Non-Streaming Response Payload
private struct AnthropicResponsePayload: Codable {
    let id: String
    let content: [ContentBlock]
    let usage: Usage
    let stop_reason: String?
    
    struct ContentBlock: Codable {
        let type: String
        let text: String
    }
    
    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

// Streaming Response Payloads
private struct AnthropicStreamEvent: Decodable {
    let type: EventType
    
    enum EventType: String, Decodable {
        case messageStart = "message_start"
        case contentBlockDelta = "content_block_delta"
        case messageDelta = "message_delta"
        case messageStop = "message_stop"
        case ping
    }
}

private struct ContentBlockDeltaEvent: Decodable {
    let delta: TextDelta
    
    struct TextDelta: Decodable {
        let type: String
        let text: String
    }
}

private struct MessageDeltaEvent: Decodable {
    let delta: MessageDelta
    let usage: MessageUsage

    struct MessageDelta: Decodable {
        let stop_reason: String?
    }
    struct MessageUsage: Decodable {
        let output_tokens: Int
    }
}

// For Token Counting
private struct AnthropicTokenCountRequest: Codable {
    let model: String
    let messages: [AnthropicMessage]
}

private struct AnthropicTokenCountResponse: Codable {
    let input_tokens: Int
}

// For Model Listing
private struct AnthropicModelsListResponse: Codable {
    let data: [AnthropicModelInfo]
}

private struct AnthropicModelInfo: Codable, Identifiable {
    let id: String
}


// MARK: - AnthropicService Implementation
class AnthropicService: LLMServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    private let apiVersion = "2023-06-01"
    private var headers: [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": apiVersion
        ]
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Static Model Fetching
    static func fetchAvailableModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { return [] }
        
        let urlString = "https://api.anthropic.com/v1/models"
        let staticHeaders: [String: String] = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01"
        ]

        let decodedResponse: AnthropicModelsListResponse = try await LLMServiceHelper.performGETRequest(urlString: urlString, headers: staticHeaders)
        return decodedResponse.data.map { $0.id }.sorted()
    }

    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        let urlString = "\(baseURL)/messages"
        let payload = AnthropicRequestPayload(
            model: request.model,
            messages: [AnthropicMessage(role: "user", content: request.prompt)],
            max_tokens: request.configuration.maxTokens,
            temperature: request.configuration.temperature,
            stream: false
        )

        let decodedResponse: AnthropicResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )

        guard let text = decodedResponse.content.first(where: { $0.type == "text" })?.text else {
            throw LLMServiceError.noResponseText
        }

        return TranslationResponse(
            translatedText: text,
            inputTokens: decodedResponse.usage.input_tokens,
            outputTokens: decodedResponse.usage.output_tokens,
            modelUsed: request.model,
            finishReason: decodedResponse.stop_reason
        )
    }
    
    // MARK: - Streaming Translation
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlString = "\(baseURL)/messages"
                    let payload = AnthropicRequestPayload(
                        model: request.model,
                        messages: [AnthropicMessage(role: "user", content: request.prompt)],
                        max_tokens: request.configuration.maxTokens,
                        temperature: request.configuration.temperature,
                        stream: true
                    )

                    let (bytes, _) = try await LLMServiceHelper.performStreamingRequest(
                        urlString: urlString,
                        payload: payload,
                        headers: headers
                    )
                    
                    var finishReason: String?
                    var outputTokens: Int?

                    for try await line in bytes.lines {
                        if line.hasPrefix("event: ") {
                            continue
                        } else if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6)
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            guard let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: jsonData) else {
                                continue
                            }

                            switch event.type {
                            case .contentBlockDelta:
                                if let deltaEvent = try? JSONDecoder().decode(ContentBlockDeltaEvent.self, from: jsonData) {
                                    continuation.yield(StreamingTranslationChunk(
                                        textChunk: deltaEvent.delta.text,
                                        inputTokens: nil,
                                        outputTokens: nil,
                                        finishReason: nil
                                    ))
                                }
                            case .messageDelta:
                                if let messageDelta = try? JSONDecoder().decode(MessageDeltaEvent.self, from: jsonData) {
                                    finishReason = messageDelta.delta.stop_reason
                                    outputTokens = messageDelta.usage.output_tokens
                                }
                            case .messageStop:
                                let finalChunk = StreamingTranslationChunk(textChunk: "", inputTokens: nil, outputTokens: outputTokens, finishReason: finishReason ?? "end_turn")
                                continuation.yield(finalChunk)
                                continuation.finish()
                                return
                            default:
                                continue
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
        let request = TranslationRequest(
            prompt: prompt,
            configuration: .init(provider: .anthropic),
            model: "claude-3-5-sonnet-20240620"
        )
        
        let response = try await self.translate(request: request)
        
        guard let jsonData = response.translatedText.data(using: .utf8) else {
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
        let urlString = "\(baseURL)/messages/count_tokens"
        let payload = AnthropicTokenCountRequest(
            model: model,
            messages: [AnthropicMessage(role: "user", content: text)]
        )
        
        let decodedResponse: AnthropicTokenCountResponse = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )
        return decodedResponse.input_tokens
    }
}
