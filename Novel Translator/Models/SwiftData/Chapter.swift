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
    
    var translationVersions: [TranslationVersion] = []
    
    enum TranslationStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case inProgress = "In Progress"
        case completed = "Completed"
        case needsReview = "Needs Review"
    }
    
    init(title: String, chapterNumber: Int, rawContent: String) {
        self.title = title
        self.chapterNumber = chapterNumber
        self.rawContent = rawContent
        self.wordCount = rawContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.translationStatus = .pending
    }
}
