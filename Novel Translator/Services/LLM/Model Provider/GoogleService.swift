import Foundation

// MARK: - Codable Structs for Translation
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
        let required = ["originalTerm", "translation", "category"]
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
    let name: String
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


// MARK: - GoogleService Implementation
class GoogleService: LLMServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
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
    static func fetchAvailableModels(apiKey: String?, baseURL: String? = nil) async throws -> [String] { // baseURL ignored
        guard let apiKey = apiKey, !apiKey.isEmpty else { return [] }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        
        let decodedResponse: ModelsListResponse = try await LLMServiceHelper.performGETRequest(urlString: endpoint, headers: [:])
        
        let filteredModels = decodedResponse.models
            .filter { $0.supportedGenerationMethods.contains("generateContent") }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }
            .sorted()
        
        return filteredModels
    }

    // MARK: - Token Counting
    func countTokens(text: String, model: String) async throws -> Int {
        guard !apiKey.isEmpty else { throw LLMServiceError.apiKeyMissing("Google") }
        
        let urlString = "\(baseURL)/\(model):countTokens?key=\(apiKey)"
        let requestPayload = CountTokensRequestPayload(
            contents: [.init(parts: [.init(text: text)])]
        )
        
        let decodedResponse: CountTokensResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: requestPayload,
            headers: [:]
        )
        return decodedResponse.totalTokens
    }
    
    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        guard !apiKey.isEmpty else { throw LLMServiceError.apiKeyMissing("Google") }
        
        let urlString = "\(baseURL)/\(request.model):generateContent?key=\(apiKey)"
        
        let requestPayload = GeminiRequestPayload(
            contents: [.init(parts: [.init(text: request.prompt)])],
            safetySettings: safetySettings
        )
        
        let decodedResponse: GeminiResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: requestPayload,
            headers: [:]
        )
        
        guard let translatedText = decodedResponse.candidates.first?.content?.parts.first?.text else {
            throw LLMServiceError.noResponseText
        }
        
        return TranslationResponse(
            translatedText: translatedText,
            inputTokens: decodedResponse.usageMetadata?.promptTokenCount,
            outputTokens: decodedResponse.usageMetadata?.candidatesTokenCount,
            modelUsed: request.model,
            finishReason: decodedResponse.candidates.first?.finishReason
        )
    }

    // MARK: - Streaming Translation
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !apiKey.isEmpty else { throw LLMServiceError.apiKeyMissing("Google") }
                    
                    let urlString = "\(baseURL)/\(request.model):streamGenerateContent?key=\(apiKey)&alt=sse"
                    
                    let requestPayload = GeminiRequestPayload(
                        contents: [.init(parts: [.init(text: request.prompt)])],
                        safetySettings: safetySettings
                    )
                    
                    let (bytes, _) = try await LLMServiceHelper.performStreamingRequest(
                        urlString: urlString,
                        payload: requestPayload,
                        headers: [:]
                    )
                    
                    for try await line in bytes.lines {
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
                                
                                if chunk.isFinal {
                                    continuation.finish()
                                    return
                                }
                                
                            } catch {
                                print("Streaming decode error on a chunk: \(error)")
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
    func extractGlossary(prompt: String, model: String) async throws -> [GlossaryEntry] {
        guard !apiKey.isEmpty else { throw LLMServiceError.apiKeyMissing("Google") }
        
        // Gemini's controlled-schema JSON output works best with specific models.
        // We will ignore the user's selected model for this specific feature and use one known to work well.
        let modelToUse = "gemini-1.5-flash-latest"
        let urlString = "\(baseURL)/\(modelToUse):generateContent?key=\(apiKey)"
        
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
                    "contextDescription": .init(type: "string", description: "A brief explanation of the term's context or meaning in the story."),
                    "gender": .init(
                        type: "string",
                        description: "The character's gender, if applicable.",
                        enum: GlossaryEntry.Gender.allCases.map { $0.rawValue }
                    )
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
        
        let decodedResponse: GeminiResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: requestPayload,
            headers: [:]
        )
        
        guard let jsonText = decodedResponse.candidates.first?.content?.parts.first?.text, !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
}
