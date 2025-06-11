import Foundation

// MARK: - Codable Structs for Translation (/generateContent)
private struct GeminiRequestPayload: Codable {
    let contents: [Content]
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
}

private struct GeminiResponsePayload: Codable {
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?

    struct Candidate: Codable {
        let content: Content?
        let finishReason: String?
    }
    
    struct Content: Codable {
        let parts: [Part]
        let role: String
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct UsageMetadata: Codable {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
    }
}

// MARK: - Codable Structs for Model Listing (/models)
private struct ModelsListResponse: Codable {
    let models: [ModelInfo]
}

struct ModelInfo: Codable, Identifiable {
    var id: String { name }
    let name: String // e.g., "models/gemini-1.5-pro-latest"
    let displayName: String
    let supportedGenerationMethods: [String]
}


// MARK: - Custom Errors
enum GeminiError: LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case noResponseText
    case invalidURL
    case responseDecodingFailed(Error)
    case modelFetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "The provided Google AI API Key is invalid or missing."
        case .apiError(let message): "The API returned an error: \(message)"
        case .noResponseText: "The API response did not contain any translated text."
        case .invalidURL: "Could not create a valid URL for the Gemini API endpoint."
        case .responseDecodingFailed(let error): "Failed to decode the API response: \(error.localizedDescription)"
        case .modelFetchFailed(let message): "Failed to fetch model list: \(message)"
        }
    }
}

// MARK: - GoogleService Implementation
class GoogleService: LLMServiceProtocol {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Static Model Fetching
    static func fetchAvailableModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { return [] }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw GeminiError.modelFetchFailed("Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(ModelsListResponse.self, from: data)
            
            let filteredModels = decodedResponse.models
                .filter { $0.supportedGenerationMethods.contains("generateContent") }
                .map { $0.name.replacingOccurrences(of: "models/", with: "") } // Return just the name, e.g., "gemini-1.5-pro-latest"
                .sorted()
            
            return filteredModels
        } catch {
            throw GeminiError.responseDecodingFailed(error)
        }
    }
    
    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }
        
        let model = request.configuration.model
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestPayload = GeminiRequestPayload(
            contents: [.init(parts: [.init(text: request.prompt)])]
        )
        urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw GeminiError.apiError("Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
        }
        
        let decodedResponse: GeminiResponsePayload
        do {
            decodedResponse = try JSONDecoder().decode(GeminiResponsePayload.self, from: data)
        } catch {
            throw GeminiError.responseDecodingFailed(error)
        }
        
        guard let translatedText = decodedResponse.candidates.first?.content?.parts.first?.text else {
            throw GeminiError.noResponseText
        }
        
        return TranslationResponse(
            translatedText: translatedText,
            inputTokens: decodedResponse.usageMetadata?.promptTokenCount,
            outputTokens: decodedResponse.usageMetadata?.candidatesTokenCount,
            modelUsed: model,
            finishReason: decodedResponse.candidates.first?.finishReason
        )
    }

    // MARK: - Streaming Translation
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }
                    
                    let model = request.configuration.model
                    // NOTE: The endpoint path and query parameter are different for streaming
                    let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse"
                    
                    guard let url = URL(string: endpoint) else {
                        throw GeminiError.invalidURL
                    }
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let requestPayload = GeminiRequestPayload(
                        contents: [.init(parts: [.init(text: request.prompt)])]
                    )
                    urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
                    
                    // Use URLSession's async bytes stream
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw GeminiError.apiError("Invalid response: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    }
                    
                    // Process each line from the Server-Sent Events stream
                    for try await line in bytes.lines {
                        // SSE format is "data: { ...JSON... }"
                        if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6)
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let decodedChunk = try JSONDecoder().decode(GeminiResponsePayload.self, from: jsonData)
                                
                                let chunkText = decodedChunk.candidates.first?.content?.parts.first?.text ?? ""
                                
                                let chunk = StreamingTranslationChunk(
                                    textChunk: chunkText,
                                    inputTokens: decodedChunk.usageMetadata?.promptTokenCount,
                                    outputTokens: decodedChunk.usageMetadata?.candidatesTokenCount,
                                    finishReason: decodedChunk.candidates.first?.finishReason
                                )
                                continuation.yield(chunk)
                                
                                // If this is the final chunk, end the stream.
                                if chunk.isFinal {
                                    continuation.finish()
                                    return
                                }
                                
                            } catch {
                                // This might catch errors on intermediate, non-final JSON chunks
                                print("Streaming decode error on a chunk: \(error)")
                            }
                        }
                    }
                    // If the loop finishes without a "finishReason", we finish manually.
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
