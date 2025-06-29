import Foundation

struct TranslationVersion: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String? // New optional property for manual snapshots
    var versionNumber: Int
    var content: String
    var createdDate: Date = Date()
    var llmModel: String
    var promptUsed: String?
    var tokensUsed: Int?
    var translationTime: TimeInterval?
    var isCurrentVersion: Bool
    
    init(versionNumber: Int, content: String, llmModel: String, promptUsed: String? = nil, tokensUsed: Int? = nil, translationTime: TimeInterval? = nil, isCurrentVersion: Bool = true, name: String? = nil) {
        self.id = UUID()
        self.versionNumber = versionNumber
        self.content = content
        self.llmModel = llmModel
        self.promptUsed = promptUsed
        self.tokensUsed = tokensUsed
        self.translationTime = translationTime
        self.isCurrentVersion = isCurrentVersion
        self.name = name
    }
    
    // Custom coding keys to handle the new optional field gracefully
    enum CodingKeys: String, CodingKey {
        case id, name, versionNumber, content, createdDate, llmModel, promptUsed, tokensUsed, translationTime, isCurrentVersion
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        versionNumber = try container.decode(Int.self, forKey: .versionNumber)
        content = try container.decode(String.self, forKey: .content)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        llmModel = try container.decode(String.self, forKey: .llmModel)
        promptUsed = try container.decodeIfPresent(String.self, forKey: .promptUsed)
        tokensUsed = try container.decodeIfPresent(Int.self, forKey: .tokensUsed)
        translationTime = try container.decodeIfPresent(TimeInterval.self, forKey: .translationTime)
        // Handle older files that might not have this key. Default to false, it will be corrected on next load by ProjectManager.
        isCurrentVersion = try container.decodeIfPresent(Bool.self, forKey: .isCurrentVersion) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(versionNumber, forKey: .versionNumber)
        try container.encode(content, forKey: .content)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(llmModel, forKey: .llmModel)
        try container.encodeIfPresent(promptUsed, forKey: .promptUsed)
        try container.encodeIfPresent(tokensUsed, forKey: .tokensUsed)
        try container.encodeIfPresent(translationTime, forKey: .translationTime)
        try container.encode(isCurrentVersion, forKey: .isCurrentVersion)
    }
}
