//
//  TranslationResponse.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

struct TranslationResponse {
    let translatedText: String
    let inputTokens: Int?
    let outputTokens: Int?
    let modelUsed: String
    let finishReason: String?
}
