import Foundation
import Tiktoken

// MARK: - Custom Errors
enum OpenAIError: LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case noResponseText
    case invalidURL
    case responseDecodingFailed(Error)
    case modelFetchFailed(String)
    case glossaryExtractionFailed(String)
    case streamingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "The provided OpenAI API Key is invalid or missing."
        case .apiError(let message): "The API returned an error: \(message)"
        case .noResponseText: "The API response did not contain any text."
        case .invalidURL: "Could not create a valid URL for the OpenAI API endpoint."
        case .responseDecodingFailed(let error): "Failed to decode the API response: \(error.localizedDescription)"
        case .modelFetchFailed(let message): "Failed to fetch model list: \(message)"
        case .glossaryExtractionFailed(let message): "Failed to extract glossary: \(message)"
        case .streamingError(let message): "An error occurred during streaming: \(message)"
        }
    }
}

// MARK: - Codable Structs for API Communication

// Request Payloads
private struct OpenAIRequestPayload: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double?
    let max_tokens: Int?
    let stream: Bool
    let response_format: ResponseFormat?

    struct ResponseFormat: Codable {
        let type: String
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

// Non-Streaming Response Payload
private struct OpenAIResponsePayload: Codable {
    let id: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}

private struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
}

// Streaming Response Chunk Payload
private struct OpenAIStreamChunk: Codable {
    let id: String
    let choices: [OpenAIStreamChoice]
}

private struct OpenAIStreamChoice: Codable {
    let delta: OpenAIStreamDelta
    let finish_reason: String?
}

private struct OpenAIStreamDelta: Codable {
    let content: String?
}

// Model Listing Response
private struct OpenAIModelsListResponse: Codable {
    let data: [OpenAIModelInfo]
}

private struct OpenAIModelInfo: Codable {
    let id: String
    let owned_by: String
}


// MARK: - OpenAIService Implementation
class OpenAIService: LLMServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Static Model Fetching
    static func fetchAvailableModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { return [] }
        
        let endpoint = "https://api.openai.com/v1/models"
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw OpenAIError.modelFetchFailed("Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(OpenAIModelsListResponse.self, from: data)
            
            // Filter for common, useful models and sort them
            let filteredModels = decodedResponse.data
                .filter { $0.id.hasPrefix("gpt-") && !$0.id.contains("vision") }
                .map { $0.id }
                .sorted()
            
            return filteredModels
        } catch {
            throw OpenAIError.responseDecodingFailed(error)
        }
    }

    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }

        let payload = OpenAIRequestPayload(
            model: request.model,
            messages: [OpenAIMessage(role: "user", content: request.prompt)],
            temperature: request.configuration.temperature,
            max_tokens: request.configuration.maxTokens,
            stream: false,
            response_format: nil
        )

        let urlRequest = try buildURLRequest(url: url, payload: payload)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        try handleResponseError(response: response, data: data)

        let decodedResponse: OpenAIResponsePayload
        do {
            decodedResponse = try JSONDecoder().decode(OpenAIResponsePayload.self, from: data)
        } catch {
            throw OpenAIError.responseDecodingFailed(error)
        }

        guard let text = decodedResponse.choices.first?.message.content else {
            throw OpenAIError.noResponseText
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
                    guard let url = URL(string: "\(baseURL)/chat/completions") else {
                        throw OpenAIError.invalidURL
                    }

                    let payload = OpenAIRequestPayload(
                        model: request.model,
                        messages: [OpenAIMessage(role: "user", content: request.prompt)],
                        temperature: request.configuration.temperature,
                        max_tokens: request.configuration.maxTokens,
                        stream: true,
                        response_format: nil
                    )

                    let urlRequest = try buildURLRequest(url: url, payload: payload)
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    try handleResponseError(response: response)

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6)
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            do {
                                let decodedChunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)
                                let choice = decodedChunk.choices.first
                                
                                let chunk = StreamingTranslationChunk(
                                    textChunk: choice?.delta.content ?? "",
                                    inputTokens: nil, // OpenAI stream does not provide token counts per chunk
                                    outputTokens: nil,
                                    finishReason: choice?.finish_reason
                                )
                                continuation.yield(chunk)

                                if chunk.isFinal {
                                    continuation.finish()
                                    return
                                }
                            } catch {
                                print("OpenAI stream decoding error on a chunk: \(error)")
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
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }

        let payload = OpenAIRequestPayload(
            model: "gpt-4o", // Use a smart model for JSON mode
            messages: [OpenAIMessage(role: "user", content: prompt)],
            temperature: 0.1,
            max_tokens: nil,
            stream: false,
            response_format: .init(type: "json_object")
        )

        let urlRequest = try buildURLRequest(url: url, payload: payload)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        try handleResponseError(response: response, data: data, forGlossary: true)

        let decodedResponse: OpenAIResponsePayload
        do {
            decodedResponse = try JSONDecoder().decode(OpenAIResponsePayload.self, from: data)
        } catch {
            throw OpenAIError.responseDecodingFailed(error)
        }
        
        guard let jsonText = decodedResponse.choices.first?.message.content else {
            return [] // If the model returns nothing, assume no entries.
        }
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw OpenAIError.responseDecodingFailed(URLError(.cannotDecodeContentData))
        }

        do {
            // Use the flexible shared wrapper. This will use the robust GlossaryEntry decoder internally.
            let wrapper = try JSONDecoder().decode(GlossaryResponseWrapper.self, from: jsonData)
            return wrapper.entries
        } catch {
            throw OpenAIError.responseDecodingFailed(error)
        }
    }

    // MARK: - Token Counting
    func countTokens(text: String, model: String) async throws -> Int {
        do {
            //let encodingName = Model.getEncoding(model)?.name ?? "cl100k_base"
            let count = try await getTokenCount(for: text, model: model)
            return count
        } catch {
            throw OpenAIError.apiError("Token counting failed via Tiktoken: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers
    private func buildURLRequest(url: URL, payload: some Encodable) throws -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }
    
    private func handleResponseError(response: URLResponse, data: Data? = nil, forGlossary: Bool = false) throws {
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            var errorMessage = "Status Code: \(statusCode)."
            if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                errorMessage += " Body: \(errorBody)"
            }
            if forGlossary {
                throw OpenAIError.glossaryExtractionFailed(errorMessage)
            } else {
                throw OpenAIError.apiError(errorMessage)
            }
        }
    }
}
