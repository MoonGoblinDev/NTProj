//
//  TranslationVersion.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class TranslationVersion {
    @Attribute(.unique) var id: UUID
    var versionNumber: Int
    var content: String
    var createdDate: Date
    var llmModel: String
    var promptUsed: String?
    var tokensUsed: Int?
    var translationTime: TimeInterval?
    var isCurrentVersion: Bool
    
    // Relationships
    var chapter: Chapter?
    
    init(versionNumber: Int, content: String, llmModel: String, promptUsed: String? = nil, tokensUsed: Int? = nil, translationTime: TimeInterval? = nil, isCurrentVersion: Bool = true) {
        self.id = UUID()
        self.versionNumber = versionNumber
        self.content = content
        self.createdDate = Date()
        self.llmModel = llmModel
        self.promptUsed = promptUsed
        self.tokensUsed = tokensUsed
        self.translationTime = translationTime
        self.isCurrentVersion = isCurrentVersion
    }
}
