// FILE: Novel Translator/Services/LLM/Model Provider/OllamaService.swift
//
//  OllamaService.swift
//  Novel Translator
//
//  Created by [Your Name] on [Date]
//

import Foundation
import Tiktoken

// MARK: - Codable Structs for Ollama API (/api/chat)
private struct OllamaChatRequestPayload: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let format: String? // "json" for JSON mode
    let options: OllamaOptions?

    struct OllamaOptions: Codable {
        let temperature: Double?
        let num_predict: Int? // Corresponds to max_tokens
    }
}

private struct OllamaChatMessage: Codable {
    let role: String // "system", "user", "assistant"
    let content: String
}

// Non-streaming response
private struct OllamaChatResponsePayload: Codable {
    let model: String
    let created_at: String
    let message: OllamaChatMessage? // Optional because streaming chunks are different
    let done: Bool
    let total_duration: Int?
    let load_duration: Int?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int?
    let eval_count: Int?
    let eval_duration: Int?

    // For streaming, the response is a series of these objects,
    // where `message` contains the content chunk.
    // The final streaming object will have `done: true` and an empty `message.content`.
}

// MARK: - Codable Structs for Ollama API (/api/tags)
private struct OllamaTagsResponse: Codable {
    let models: [OllamaModelInfo]
}

private struct OllamaModelInfo: Codable {
    let name: String // e.g., "llama3:latest"
    let modified_at: String
    let size: Int
    // digest, details, etc. are also available but not strictly needed for model listing
}


// MARK: - OllamaService Implementation
class OllamaService: LLMServiceProtocol {
    private let baseURL: String // e.g., "http://localhost:11434"
    private var headers: [String: String] {
        // Ollama typically doesn't require auth headers for local instances
        [:]
    }

    init(baseURL: String) {
        // Ensure baseURL doesn't end with a slash for clean path appending
        if baseURL.hasSuffix("/") {
            self.baseURL = String(baseURL.dropLast())
        } else {
            self.baseURL = baseURL
        }
    }

    // MARK: - Static Model Fetching
    static func fetchAvailableModels(apiKey: String?, baseURL: String?) async throws -> [String] {
        guard let baseURL = baseURL, !baseURL.isEmpty, let url = URL(string: "\(baseURL)/api/tags") else {
            throw LLMServiceError.invalidURL("Ollama base URL for fetching models is invalid or missing.")
        }
        
        let decodedResponse: OllamaTagsResponse = try await LLMServiceHelper.performGETRequest(
            urlString: url.absoluteString,
            headers: [:] // Ollama typically doesn't need auth for /api/tags
        )
        
        return decodedResponse.models.map { $0.name }.sorted()
    }

    // MARK: - Non-Streaming Translation
    func translate(request: TranslationRequest) async throws -> TranslationResponse {
        let urlString = "\(baseURL)/api/chat"
        let payload = OllamaChatRequestPayload(
            model: request.model,
            messages: [OllamaChatMessage(role: "user", content: request.prompt)],
            stream: false,
            format: nil,
            options: .init(
                temperature: request.configuration.temperature,
                num_predict: request.configuration.maxTokens
            )
        )

        let decodedResponse: OllamaChatResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )

        guard let text = decodedResponse.message?.content else {
            throw LLMServiceError.noResponseText
        }

        return TranslationResponse(
            translatedText: text,
            inputTokens: decodedResponse.prompt_eval_count, // Ollama provides eval_count for prompt
            outputTokens: decodedResponse.eval_count, // and for generated response
            modelUsed: request.model,
            finishReason: decodedResponse.done ? "stop" : nil // Simple mapping
        )
    }
    
    // MARK: - Streaming Translation
    func streamTranslate(request: TranslationRequest) -> AsyncThrowingStream<StreamingTranslationChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlString = "\(baseURL)/api/chat"
                    let payload = OllamaChatRequestPayload(
                        model: request.model,
                        messages: [OllamaChatMessage(role: "user", content: request.prompt)],
                        stream: true,
                        format: nil,
                        options: .init(
                            temperature: request.configuration.temperature,
                            num_predict: request.configuration.maxTokens
                        )
                    )

                    let (bytes, _) = try await LLMServiceHelper.performStreamingRequest(
                        urlString: urlString,
                        payload: payload,
                        headers: headers
                    )
                    
                    var finalPromptTokens: Int?
                    var finalCompletionTokens: Int?
                    var finishReason: String?

                    for try await line in bytes.lines {
                        guard !line.isEmpty, let jsonData = line.data(using: .utf8) else { continue }
                        
                        do {
                            let decodedChunk = try JSONDecoder().decode(OllamaChatResponsePayload.self, from: jsonData)
                            
                            let textChunk = decodedChunk.message?.content ?? ""
                            
                            if decodedChunk.done {
                                finalPromptTokens = decodedChunk.prompt_eval_count
                                finalCompletionTokens = decodedChunk.eval_count
                                finishReason = "stop"
                                
                                // Send one last chunk with potential final token counts and finish reason
                                continuation.yield(StreamingTranslationChunk(
                                    textChunk: textChunk, // May be empty on final 'done' message
                                    inputTokens: finalPromptTokens,
                                    outputTokens: finalCompletionTokens,
                                    finishReason: finishReason
                                ))
                                continuation.finish()
                                return
                            } else {
                                continuation.yield(StreamingTranslationChunk(
                                    textChunk: textChunk,
                                    inputTokens: nil, // Token counts usually come with the final 'done' message
                                    outputTokens: nil,
                                    finishReason: nil
                                ))
                            }
                        } catch {
                            // Log or handle individual chunk decoding errors if necessary
                            print("Ollama stream decoding error on a chunk: \(error) - Data: \(line)")
                            // Decide if we should continue or rethrow. For now, try to continue.
                        }
                    }
                    // If the loop finishes without a 'done: true' message with details (unlikely for well-behaved Ollama stream), finish gracefully.
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Glossary Extraction
    func extractGlossary(prompt: String, model: String) async throws -> [GlossaryEntry] {
        let urlString = "\(baseURL)/api/chat"
        let modelToUse = model.isEmpty ? "llama3" : model
        let payload = OllamaChatRequestPayload(
            model: modelToUse,
            messages: [OllamaChatMessage(role: "user", content: prompt)],
            stream: false,
            format: "json", // Request JSON output
            options: .init(temperature: 0.1, num_predict: nil)
        )

        let decodedResponse: OllamaChatResponsePayload = try await LLMServiceHelper.performRequest(
            urlString: urlString,
            payload: payload,
            headers: headers
        )
        
        guard let jsonText = decodedResponse.message?.content else {
            print("Ollama extractGlossary: No content in response.")
            return []
        }
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMServiceError.responseDecodingFailed(URLError(.cannotDecodeContentData))
        }

        do {
            let wrapper = try JSONDecoder().decode(GlossaryResponseWrapper.self, from: jsonData)
            return wrapper.entries
        } catch {
            print("Ollama extractGlossary decoding error: \(error). JSON Text: \(jsonText)")
            throw LLMServiceError.responseDecodingFailed(error)
        }
    }

    // MARK: - Token Counting
    func countTokens(text: String, model: String) async throws -> Int {
        do {
            let count = try await getTokenCount(for: text, model: "gpt-4")
            return count
        } catch {
            throw LLMServiceError.serviceNotImplemented("Token counting failed via Tiktoken for Ollama: \(error.localizedDescription)")
        }
    }
}
