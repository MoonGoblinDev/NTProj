// FILE: Novel Translator/Models/DTOs/OpenAICompatibleDTOs.swift
//
//  OpenAICompatibleDTOs.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 24/06/25.
//
//  This file contains shared DTOs for OpenAI and any OpenAI-compatible services like OpenRouter.
//

import Foundation

// MARK: - Request Payloads
struct OpenAIRequestPayload: Codable {
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

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Non-Streaming Response Payload
struct OpenAIResponsePayload: Codable {
    let id: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}

struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
}

// MARK: - Streaming Response Chunk Payload
struct OpenAIStreamChunk: Codable {
    let id: String
    let choices: [OpenAIStreamChoice]
}

struct OpenAIStreamChoice: Codable {
    let delta: OpenAIStreamDelta
    let finish_reason: String?
}

struct OpenAIStreamDelta: Codable {
    let content: String?
}

// MARK: - Model Listing Response
struct OpenAIModelsListResponse: Codable {
    let data: [OpenAIModelInfo]
}

struct OpenAIModelInfo: Codable {
    let id: String
    let owned_by: String? // <-- THIS IS THE FIX: Changed from String to String?
}
