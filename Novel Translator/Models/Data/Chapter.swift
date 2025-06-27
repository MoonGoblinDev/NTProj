import Foundation

struct Chapter: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var chapterNumber: Int
    var rawContent: String
    var translatedContent: String?
    var wordCount: Int
    var translationStatus: TranslationStatus
    var createdDate: Date = Date()
    var lastTranslatedDate: Date?
    var estimatedTokens: Int?
    var originalFilename: String? // New property
    
    var translationVersions: [TranslationVersion] = []
    
    var sourceLineCount: Int {
        guard !rawContent.isEmpty else { return 0 }
        return rawContent.components(separatedBy: .newlines).count
    }
    
    var translatedLineCount: Int {
        guard let content = translatedContent, !content.isEmpty else { return 0 }
        return content.components(separatedBy: .newlines).count
    }
    
    enum TranslationStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case inProgress = "In Progress"
        case completed = "Completed"
        case needsReview = "Needs Review"
    }
    
    init(title: String, chapterNumber: Int, rawContent: String, originalFilename: String? = nil) {
        self.title = title
        self.chapterNumber = chapterNumber
        self.rawContent = rawContent
        self.wordCount = rawContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.translationStatus = .pending
        self.originalFilename = originalFilename
    }
    
    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey {
        case id, title, chapterNumber, rawContent, translatedContent, wordCount, translationStatus, createdDate, lastTranslatedDate, estimatedTokens, originalFilename, translationVersions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        chapterNumber = try container.decode(Int.self, forKey: .chapterNumber)
        rawContent = try container.decode(String.self, forKey: .rawContent)
        translatedContent = try container.decodeIfPresent(String.self, forKey: .translatedContent)
        wordCount = try container.decode(Int.self, forKey: .wordCount)
        translationStatus = try container.decode(TranslationStatus.self, forKey: .translationStatus)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastTranslatedDate = try container.decodeIfPresent(Date.self, forKey: .lastTranslatedDate)
        estimatedTokens = try container.decodeIfPresent(Int.self, forKey: .estimatedTokens)
        originalFilename = try container.decodeIfPresent(String.self, forKey: .originalFilename)
        translationVersions = try container.decodeIfPresent([TranslationVersion].self, forKey: .translationVersions) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(chapterNumber, forKey: .chapterNumber)
        try container.encode(rawContent, forKey: .rawContent)
        try container.encodeIfPresent(translatedContent, forKey: .translatedContent)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encode(translationStatus, forKey: .translationStatus)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(lastTranslatedDate, forKey: .lastTranslatedDate)
        try container.encodeIfPresent(estimatedTokens, forKey: .estimatedTokens)
        try container.encodeIfPresent(originalFilename, forKey: .originalFilename)
        try container.encode(translationVersions, forKey: .translationVersions)
    }
}
