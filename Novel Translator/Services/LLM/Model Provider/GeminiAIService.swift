import Foundation

// MARK: - Codable Structs for Translation (/generateContent)
private struct GeminiRequestPayload: Codable {
    let contents: [Content]
    let safetySettings: [SafetySetting]
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct SafetySetting: Codable {
        let category: String
        let threshold: String
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

// MARK: - Codable Structs for Glossary Extraction (JSON Mode)
private struct GeminiGlossaryRequestPayload: Encodable {
    let contents: [GeminiRequestPayload.Content]
    let safetySettings: [GeminiRequestPayload.SafetySetting]
    let generationConfig: GenerationConfig
    
    struct GenerationConfig: Encodable {
        let responseMimeType: String
        let responseSchema: Schema
        
        enum CodingKeys: String, CodingKey {
            case responseMimeType = "response_mime_type"
            case responseSchema = "response_schema"
        }
    }
    
    struct Schema: Encodable {
        let type = "array"
        let items: ItemsSchema
    }
    
    struct ItemsSchema: Encodable {
        let type = "object"
        let properties: [String: Property]
        let required = ["originalTerm", "translation", "category", "contextDescription"]
    }
    
    struct Property: Encodable {
        let type: String
        let description: String?
        let `enum`: [String]?

        init(type: String, description: String? = nil, `enum`: [String]? = nil) {
            self.type = type
            self.description = description
            self.`enum` = `enum`
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case contents, safetySettings
        case generationConfig = "generation_config"
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

// MARK: - Codable Structs for Token Counting (/countTokens)
private struct CountTokensRequestPayload: Codable {
    let contents: [GeminiRequestPayload.Content]
}

private struct CountTokensResponsePayload: Codable {
    let totalTokens: Int
}


// MARK: - Custom Errors
enum GeminiError: LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case noResponseText
    case invalidURL
    case responseDecodingFailed(Error)
    case modelFetchFailed(String)
    case tokenCountFailed(String)
    case glossaryExtractionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "The provided Google AI API Key is invalid or missing."
        case .apiError(let message): "The API returned an error: \(message)"
        case .noResponseText: "The API response did not contain any translated text."
        case .invalidURL: "Could not create a valid URL for the Gemini API endpoint."
        case .responseDecodingFailed(let error): "Failed to decode the API response: \(error.localizedDescription)"
        case .modelFetchFailed(let message): "Failed to fetch model list: \(message)"
        case .tokenCountFailed(let message): "Failed to count tokens: \(message)"
        case .glossaryExtractionFailed(let message): "Failed to extract glossary: \(message)"
        }
    }
}

// MARK: - GoogleService Implementation
class GoogleService: LLMServiceProtocol {
    private let apiKey: String
    
    // Safety settings to disable all safety filters
    private let safetySettings = [
        GeminiRequestPayload.SafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE"),
        GeminiRequestPayload.SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE"),
        GeminiRequestPayload.SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE"),
        GeminiRequestPayload.SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE"),
        GeminiRequestPayload.SafetySetting(category: "HARM_CATEGORY_CIVIC_INTEGRITY", threshold: "BLOCK_NONE")
    ]
    
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

    // MARK: - Token Counting
    func countTokens(text: String, model: String) async throws -> Int {
        guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):countTokens?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else { throw GeminiError.invalidURL }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // The payload for counting without safety settings
        let requestPayload = CountTokensRequestPayload(
            contents: [.init(parts: [.init(text: text)])]
        )
        urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw GeminiError.tokenCountFailed("Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(CountTokensResponsePayload.self, from: data)
            return decodedResponse.totalTokens
        } catch {
            throw GeminiError.responseDecodingFailed(error)
        }
    }
    
    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }
        
        let model = request.model
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestPayload = GeminiRequestPayload(
            contents: [.init(parts: [.init(text: request.prompt)])],
            safetySettings: safetySettings
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
                    
                    let model = request.model
                    // NOTE: The endpoint path and query parameter are different for streaming
                    let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse"
                    
                    guard let url = URL(string: endpoint) else {
                        throw GeminiError.invalidURL
                    }
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let requestPayload = GeminiRequestPayload(
                        contents: [.init(parts: [.init(text: request.prompt)])],
                        safetySettings: safetySettings
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
    
    // MARK: - Glossary Extraction
    func extractGlossary(prompt: String) async throws -> [GlossaryEntry] {
        guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }
        
        // Use a model that supports JSON mode well, like 1.5 Flash or Pro.
        let model = "gemini-1.5-flash-latest"
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else { throw GeminiError.invalidURL }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Define the JSON schema for the response
        let schema = GeminiGlossaryRequestPayload.Schema(
            items: .init(
                properties: [
                    "originalTerm": .init(type: "string", description: "The term in the source language."),
                    "translation": .init(type: "string", description: "The term translated into the target language."),
                    "category": .init(
                        type: "string",
                        description: "The category of the term.",
                        enum: GlossaryEntry.GlossaryCategory.allCases.map { $0.rawValue }
                    ),
                    "contextDescription": .init(type: "string", description: "A brief explanation of the term's context or meaning in the story.")
                ]
            )
        )

        let generationConfig = GeminiGlossaryRequestPayload.GenerationConfig(
            responseMimeType: "application/json",
            responseSchema: schema
        )
        
        let requestPayload = GeminiGlossaryRequestPayload(
            contents: [.init(parts: [.init(text: prompt)])],
            safetySettings: safetySettings,
            generationConfig: generationConfig
        )
        
        urlRequest.httpBody = try JSONEncoder().encode(requestPayload)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw GeminiError.glossaryExtractionFailed("Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
        }
        
        let decodedResponse: GeminiResponsePayload
        do {
            decodedResponse = try JSONDecoder().decode(GeminiResponsePayload.self, from: data)
        } catch {
            throw GeminiError.responseDecodingFailed(error)
        }
        
        guard let jsonText = decodedResponse.candidates.first?.content?.parts.first?.text else {
            // If there's no text part at all, it's safer to assume no entries were found.
            // This could happen if the model's response is blocked or empty.
            return []
        }
        
        // FIX: If the model returns an empty string instead of an empty JSON array "[]",
        // treat it as "no entries found" and return an empty array to prevent a crash.
        if jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        
        // The response text is a JSON string, so we need to decode it again.
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw GeminiError.responseDecodingFailed(URLError(.cannotDecodeContentData))
        }
        
        do {
            let jsonDecoder = JSONDecoder()
            let extractedEntries = try jsonDecoder.decode([GlossaryEntry].self, from: jsonData)
            return extractedEntries
        } catch {
            throw GeminiError.responseDecodingFailed(error)
        }
    }
}
