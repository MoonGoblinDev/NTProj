import Foundation

struct TranslationVersion: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var versionNumber: Int
    var content: String
    var createdDate: Date = Date()
    var llmModel: String
    var promptUsed: String?
    var tokensUsed: Int?
    var translationTime: TimeInterval?
    var isCurrentVersion: Bool
    
    init(versionNumber: Int, content: String, llmModel: String, promptUsed: String? = nil, tokensUsed: Int? = nil, translationTime: TimeInterval? = nil, isCurrentVersion: Bool = true) {
        self.versionNumber = versionNumber
        self.content = content
        self.llmModel = llmModel
        self.promptUsed = promptUsed
        self.tokensUsed = tokensUsed
        self.translationTime = translationTime
        self.isCurrentVersion = isCurrentVersion
    }
}
