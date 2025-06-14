//
//  TranslationRequest.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

struct TranslationRequest {
    let prompt: String
    let configuration: APIConfiguration
    let model: String
}
