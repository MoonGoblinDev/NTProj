//
//  AnthropicService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

// MARK: - Custom Errors
enum AnthropicError: LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case noResponseText
    case invalidURL
    case responseDecodingFailed(Error)
    case streamingError(String)
    case glossaryExtractionFailed(String)
    case tokenCountFailed(String)
    case modelFetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "The provided Anthropic API Key is invalid or missing."
        case .apiError(let message): "The API returned an error: \(message)"
        case .noResponseText: "The API response did not contain any text."
        case .invalidURL: "Could not create a valid URL for the Anthropic API endpoint."
        case .responseDecodingFailed(let error): "Failed to decode the API response: \(error.localizedDescription)"
        case .streamingError(let message): "An error occurred during streaming: \(message)"
        case .glossaryExtractionFailed(let message): "Failed to extract glossary: \(message)"
        case .tokenCountFailed(let message): "Failed to count tokens: \(message)"
        case .modelFetchFailed(let message): "Failed to fetch model list: \(message)"
        }
    }
}

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
    let token_count: Int
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

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Static Model Fetching
    static func fetchAvailableModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { return [] }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            throw AnthropicError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw AnthropicError.modelFetchFailed("Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
        }

        do {
            let decodedResponse = try JSONDecoder().decode(AnthropicModelsListResponse.self, from: data)
            let modelIds = decodedResponse.data.map { $0.id }.sorted()
            return modelIds
        } catch {
            throw AnthropicError.responseDecodingFailed(error)
        }
    }

    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidURL
        }

        let payload = AnthropicRequestPayload(
            model: request.model,
            messages: [AnthropicMessage(role: "user", content: request.prompt)],
            max_tokens: request.configuration.maxTokens,
            temperature: request.configuration.temperature,
            stream: false
        )

        let urlRequest = try buildURLRequest(url: url, payload: payload)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        try handleResponseError(response: response, data: data)

        let decodedResponse: AnthropicResponsePayload
        do {
            decodedResponse = try JSONDecoder().decode(AnthropicResponsePayload.self, from: data)
        } catch {
            throw AnthropicError.responseDecodingFailed(error)
        }

        guard let text = decodedResponse.content.first(where: { $0.type == "text" })?.text else {
            throw AnthropicError.noResponseText
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
                    guard let url = URL(string: "\(baseURL)/messages") else {
                        throw AnthropicError.invalidURL
                    }

                    let payload = AnthropicRequestPayload(
                        model: request.model,
                        messages: [AnthropicMessage(role: "user", content: request.prompt)],
                        max_tokens: request.configuration.maxTokens,
                        temperature: request.configuration.temperature,
                        stream: true
                    )

                    let urlRequest = try buildURLRequest(url: url, payload: payload)
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    try handleResponseError(response: response)

                    var finishReason: String?
                    var outputTokens: Int?

                    for try await line in bytes.lines {
                        if line.hasPrefix("event: ") {
                            // We don't need to parse the event type separately for this implementation
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
                                // Send one final chunk with the stop reason
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
        // Use a powerful model for better JSON adherence
        let request = TranslationRequest(
            prompt: prompt,
            configuration: .init(provider: .anthropic), // temp config
            model: "claude-3-5-sonnet-20240620"
        )
        
        let response = try await self.translate(request: request)
        let jsonText = response.translatedText
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AnthropicError.responseDecodingFailed(URLError(.cannotDecodeContentData))
        }

        do {
            let wrapper = try JSONDecoder().decode(GlossaryResponseWrapper.self, from: jsonData)
            return wrapper.entries
        } catch {
            throw AnthropicError.responseDecodingFailed(error)
        }
    }

    // MARK: - Token Counting
    func countTokens(text: String, model: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/token_count") else {
            throw AnthropicError.invalidURL
        }

        let payload = AnthropicTokenCountRequest(
            model: model,
            messages: [AnthropicMessage(role: "user", content: text)]
        )

        let urlRequest = try buildURLRequest(url: url, payload: payload)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        try handleResponseError(response: response, data: data)

        do {
            let decodedResponse = try JSONDecoder().decode(AnthropicTokenCountResponse.self, from: data)
            return decodedResponse.token_count
        } catch {
            throw AnthropicError.responseDecodingFailed(error)
        }
    }

    // MARK: - Private Helpers
    private func buildURLRequest(url: URL, payload: some Encodable) throws -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }
    
    private func handleResponseError(response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            var errorMessage = "Status Code: \(statusCode)."
            if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                errorMessage += " Body: \(errorBody)"
            }
            throw AnthropicError.apiError(errorMessage)
        }
    }
}
