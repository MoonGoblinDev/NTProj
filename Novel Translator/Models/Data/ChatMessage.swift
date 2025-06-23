//
//  ChatMessage.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 21/06/25.
//

import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID = UUID()
    let role: Role
    let content: String
    let sources: [String]? // e.g., ["Chapter 1", "Chapter 3"]
    let timestamp: Date = Date()
    
    enum Role: String, Hashable {
        case user
        case assistant
    }
}
