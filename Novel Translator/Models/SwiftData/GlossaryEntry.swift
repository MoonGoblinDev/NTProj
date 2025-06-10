//
//  GlossaryEntry.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class GlossaryEntry {
    @Attribute(.unique) var id: UUID
    var originalTerm: String
    var translation: String
    var category: GlossaryCategory
    var contextDescription: String?
    var usageCount: Int
    var isActive: Bool
    var createdDate: Date
    var lastUsedDate: Date?
    var aliases: [String] // Alternative spellings or forms
    
    // Relationships
    var project: TranslationProject?
    
    enum GlossaryCategory: String, CaseIterable, Codable {
        case character = "character"
        case place = "place"
        case event = "event"
        case object = "object"
        case concept = "concept"
        case organization = "organization"
        case technique = "technique"
        case other = "other"
        
        var displayName: String {
            self.rawValue.capitalized
        }
    }
    
    init(originalTerm: String, translation: String, category: GlossaryCategory, contextDescription: String? = nil, aliases: [String] = []) {
        self.id = UUID()
        self.originalTerm = originalTerm
        self.translation = translation
        self.category = category
        self.contextDescription = contextDescription
        self.usageCount = 0
        self.isActive = true
        self.createdDate = Date()
        self.aliases = aliases
    }
}
