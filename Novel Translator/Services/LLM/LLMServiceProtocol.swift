//
//  LLMServiceProtocol.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

protocol LLMServiceProtocol {
    func translate(request: TranslationRequest) async throws -> TranslationResponse
}
