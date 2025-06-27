import Foundation
import SwiftUI

struct GlossaryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var originalTerm: String
    var translation: String
    var category: GlossaryCategory
    var contextDescription: String
    var gender: Gender? // New property for character gender
    var usageCount: Int = 0
    var isActive: Bool = true
    var createdDate: Date = Date()
    var lastUsedDate: Date?
    var aliases: [String] // Alternative spellings or forms
    
    enum Gender: String, CaseIterable, Codable {
        case male, female, other, unknown
        
        var displayName: String {
            self.rawValue.capitalized
        }
        
        var genderColor: Color {
            switch self {
            case .male: return Color.blue
            case .female: return Color.red
            case .other: return Color.purple
            case .unknown: return Color.indigo
            }
        }
    }
    
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
        
        var highlightColor: Color {
            switch self {
            case .character: return .glossaryCharacter
            case .place: return .glossaryPlace
            case .event: return .glossaryEvent
            case .object: return .glossaryObject
            case .concept: return .glossaryConcept
            case .organization: return .glossaryOrganization
            case .technique: return .glossaryTechnique
            case .other: return .glossaryOther
            }
        }
    }
    
    init(originalTerm: String, translation: String, category: GlossaryCategory, contextDescription: String, gender: Gender? = nil, aliases: [String] = []) {
        self.originalTerm = originalTerm
        self.translation = translation
        self.category = category
        self.contextDescription = contextDescription
        self.gender = (category == .character) ? (gender ?? .unknown) : nil // Only characters have gender
        self.aliases = aliases
    }

    // MARK: - Custom Codable Initializer for Robustness
    enum CodingKeys: String, CodingKey {
        case id, originalTerm, translation, category, contextDescription, gender, usageCount, isActive, createdDate, lastUsedDate, aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use defaults for fields that the AI might not provide.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        originalTerm = try container.decode(String.self, forKey: .originalTerm)
        translation = try container.decode(String.self, forKey: .translation)
        category = try container.decode(GlossaryCategory.self, forKey: .category)
        contextDescription = try container.decodeIfPresent(String.self, forKey: .contextDescription) ?? ""
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
        lastUsedDate = try container.decodeIfPresent(Date.self, forKey: .lastUsedDate)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []

        // Ensure gender is nil if category is not character
        if category != .character {
            gender = nil
        }
    }
    
    // Custom encode to ensure gender is only encoded for characters
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(originalTerm, forKey: .originalTerm)
        try container.encode(translation, forKey: .translation)
        try container.encode(category, forKey: .category)
        try container.encode(contextDescription, forKey: .contextDescription)
        if category == .character {
            try container.encodeIfPresent(gender, forKey: .gender)
        }
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(lastUsedDate, forKey: .lastUsedDate)
        try container.encode(aliases, forKey: .aliases)
    }
}
