//
//  Chapter.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    var title: String
    var chapterNumber: Int
    var rawContent: String
    var translatedContent: String?
    var wordCount: Int
    var translationStatus: TranslationStatus
    var createdDate: Date
    var lastTranslatedDate: Date?
    var estimatedTokens: Int?
    
    // Relationships
    var project: TranslationProject?
    
    @Relationship(deleteRule: .cascade, inverse: \TranslationVersion.chapter)
    var translationVersions: [TranslationVersion] = []
    
    enum TranslationStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case inProgress = "In Progress"
        case completed = "Completed"
        case needsReview = "Needs Review"
    }
    
    init(title: String, chapterNumber: Int, rawContent: String) {
        self.id = UUID()
        self.title = title
        self.chapterNumber = chapterNumber
        self.rawContent = rawContent
        self.wordCount = rawContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.translationStatus = .pending
        self.createdDate = Date()
    }
}
