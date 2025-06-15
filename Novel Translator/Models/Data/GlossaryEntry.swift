import Foundation
import SwiftUI

struct GlossaryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var originalTerm: String
    var translation: String
    var category: GlossaryCategory
    var contextDescription: String
    var usageCount: Int = 0
    var isActive: Bool = true
    var createdDate: Date = Date()
    var lastUsedDate: Date?
    var aliases: [String] // Alternative spellings or forms
    
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
            case .technique: return .gold
            case .other: return .glossaryOther
            }
        }
    }
    
    init(originalTerm: String, translation: String, category: GlossaryCategory, contextDescription: String, aliases: [String] = []) {
        self.originalTerm = originalTerm
        self.translation = translation
        self.category = category
        self.contextDescription = contextDescription
        self.aliases = aliases
    }

    // MARK: - Custom Codable Initializer for Robustness
    enum CodingKeys: String, CodingKey {
        case id, originalTerm, translation, category, contextDescription, usageCount, isActive, createdDate, lastUsedDate, aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use defaults for fields that the AI might not provide.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        originalTerm = try container.decode(String.self, forKey: .originalTerm)
        translation = try container.decode(String.self, forKey: .translation)
        category = try container.decode(GlossaryCategory.self, forKey: .category)
        contextDescription = try container.decodeIfPresent(String.self, forKey: .contextDescription) ?? ""
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
        lastUsedDate = try container.decodeIfPresent(Date.self, forKey: .lastUsedDate)
        // CRITICAL: Default aliases to an empty array if not present in the JSON.
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }
}
