//
//  ImportSettings.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftData
import Foundation

@Model
final class ImportSettings {
    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var fileFormat: FileFormat
    var chapterSeparator: String
    var autoDetectChapters: Bool
    var preserveFormatting: Bool
    var encoding: String
    
    enum FileFormat: String, CaseIterable, Codable {
        case txt = "txt"
        case docx = "docx"
        case epub = "epub"
        
        var displayName: String {
            rawValue.uppercased()
        }
    }
    
    init(projectId: UUID) {
        self.id = UUID()
        self.projectId = projectId
        self.fileFormat = .txt
        self.chapterSeparator = "\n\nChapter "
        self.autoDetectChapters = true
        self.preserveFormatting = false
        self.encoding = "UTF-8"
    }
}
