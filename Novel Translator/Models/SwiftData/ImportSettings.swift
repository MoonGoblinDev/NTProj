import Foundation

struct ImportSettings: Codable, Identifiable {
    var id: UUID = UUID()
    var chapterSeparator: String = "\n\nChapter "
    var autoDetectChapters: Bool = true
    var preserveFormatting: Bool = false
    var encoding: String = "UTF-8"
    
    enum FileFormat: String, CaseIterable, Codable {
        case txt = "txt"
        case docx = "docx"
        case epub = "epub"
        
        var displayName: String {
            rawValue.uppercased()
        }
    }
    
    // Note: projectId and fileFormat were removed as they are less relevant in a single-file project model.
    // This can be expanded later if needed.
}
