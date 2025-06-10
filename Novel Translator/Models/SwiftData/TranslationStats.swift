//
//  TranslationStats.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class TranslationStats {
    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var totalChapters: Int
    var completedChapters: Int
    var totalWords: Int
    var translatedWords: Int
    var totalTokensUsed: Int
    var estimatedCost: Double
    var averageTranslationTime: TimeInterval
    var lastUpdated: Date
    
    init(projectId: UUID) {
        self.id = UUID()
        self.projectId = projectId
        self.totalChapters = 0
        self.completedChapters = 0
        self.totalWords = 0
        self.translatedWords = 0
        self.totalTokensUsed = 0
        self.estimatedCost = 0.0
        self.averageTranslationTime = 0
        self.lastUpdated = Date()
    }
}
