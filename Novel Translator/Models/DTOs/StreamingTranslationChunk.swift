//
//  treamingTranslationChunk.swift.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import Foundation

// Represents a single piece of a streamed translation response.
struct StreamingTranslationChunk {
    // The chunk of text received from the stream.
    let textChunk: String
    
    // The total input tokens, usually sent with the final chunk.
    let inputTokens: Int?
    
    // The total output tokens, usually sent with the final chunk.
    let outputTokens: Int?
    
    // The reason the stream finished, sent with the final chunk.
    let finishReason: String?
    
    // Indicates if this is the last chunk in the stream.
    var isFinal: Bool {
        finishReason != nil
    }
}
