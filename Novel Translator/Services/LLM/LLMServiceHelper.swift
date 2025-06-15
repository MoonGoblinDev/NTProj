//
//  LLMServiceHelper.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 19/06/25.
//

import Foundation

// MARK: - Shared Network Error
enum LLMServiceError: LocalizedError {
    case invalidURL(String)
    case apiError(statusCode: Int, message: String)
    case responseDecodingFailed(Error)
    case apiKeyMissing(String)
    case noResponseText
    case serviceNotImplemented(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "The URL for the API endpoint is invalid: \(url)"
        case .apiError(let statusCode, let message):
            return "The API returned an error (Status Code: \(statusCode)): \(message)"
        case .responseDecodingFailed(let error):
            return "Failed to decode the API response: \(error.localizedDescription)"
        case .apiKeyMissing(let provider):
            return "API Key for \(provider) not found in Keychain. Please set it in Project Settings."
        case .noResponseText:
            return "The API response did not contain any text content."
        case .serviceNotImplemented(let feature):
            return "The feature '\(feature)' is not yet implemented for this provider."
        }
    }
}


// MARK: - LLMServiceHelper
class LLMServiceHelper {
    
    // MARK: - Non-Streaming Request (POST)
    static func performRequest<P: Encodable, R: Decodable>(
        urlString: String,
        payload: P,
        headers: [String: String]
    ) async throws -> R {
        guard let url = URL(string: urlString) else {
            throw LLMServiceError.invalidURL(urlString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleResponseError(response: response, data: data)
        
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw LLMServiceError.responseDecodingFailed(error)
        }
    }

    // MARK: - Streaming Request (POST)
    static func performStreamingRequest<P: Encodable>(
        urlString: String,
        payload: P,
        headers: [String: String]
    ) async throws -> (URLSession.AsyncBytes, URLResponse) {
        guard let url = URL(string: urlString) else {
            throw LLMServiceError.invalidURL(urlString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try handleResponseError(response: response)
        
        return (bytes, response)
    }
    
    // MARK: - Static GET Request
    static func performGETRequest<R: Decodable>(
        urlString: String,
        headers: [String: String]
    ) async throws -> R {
        guard let url = URL(string: urlString) else {
            throw LLMServiceError.invalidURL(urlString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleResponseError(response: response, data: data)
        
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw LLMServiceError.responseDecodingFailed(error)
        }
    }

    // MARK: - Error Handling
    static func handleResponseError(response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.apiError(statusCode: -1, message: "Response was not an HTTP response.")
        }
        
        guard httpResponse.statusCode == 200 else {
            var errorMessage = "An unknown error occurred."
            if let data = data, let errorBody = String(data: data, encoding: .utf8), !errorBody.isEmpty {
                errorMessage = errorBody
            }
            throw LLMServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
}
