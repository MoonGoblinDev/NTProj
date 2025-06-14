import Foundation

struct TranslationStats: Codable, Identifiable {
    var id: UUID = UUID()
    var totalChapters: Int = 0
    var completedChapters: Int = 0
    var totalWords: Int = 0
    var translatedWords: Int = 0
    var totalTokensUsed: Int = 0
    var estimatedCost: Double = 0.0
    var averageTranslationTime: TimeInterval = 0
    var lastUpdated: Date = Date()
    
    // Note: projectId removed as this struct is now nested within the project file.
}
