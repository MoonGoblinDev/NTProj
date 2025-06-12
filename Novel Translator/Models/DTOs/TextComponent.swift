//
//  TextComponent.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import Foundation

/// Represents a segment of text that can be either plain or a highlighted glossary term.
enum TextComponent: Identifiable, Hashable {
    case plain(String)
    case glossary(text: String, entry: GlossaryEntry)
    
    // Conformance for ForEach loops
    var id: String {
        switch self {
        case .plain(let text):
            return text
        case .glossary(let text, let entry):
            return text + entry.id.uuidString
        }
    }
}
