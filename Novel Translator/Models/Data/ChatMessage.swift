// FILE: Novel Translator/Models/Data/ChatMessage.swift
//
//  ChatMessage.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 21/06/25.
//

import Foundation

struct ChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let sources: [String]? // e.g., ["Chapter 1", "Chapter 3"]
    let timestamp: Date
    
    enum Role: String, Hashable, Codable {
        case user
        case assistant
    }

    // Explicit initializer to ensure all properties can be set,
    // especially for creating mock data with specific timestamps,
    // while maintaining default behavior for new messages.
    init(id: UUID = UUID(), role: Role, content: String, sources: [String]?, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.sources = sources
        self.timestamp = timestamp
    }
}
