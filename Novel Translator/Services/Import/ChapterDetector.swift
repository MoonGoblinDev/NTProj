//
//  ChapterDetector.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

// NOTE: For now, we are not using TextFileParser.swift as the logic is simple enough
// to be included directly in ChapterDetector. It can be separated later if more
// complex parsers (DOCX, EPUB) are added.

class ChapterDetector {
    /// Detects chapters from a raw string based on import settings.
    /// - Parameters:
    ///   - text: The full raw text content from a file.
    ///   - settings: The import settings defining how to split chapters.
    ///   - filename: The name of the file, used as a fallback title.
    /// - Returns: An array of `Chapter` objects.
    func detect(from text: String, using settings: ImportSettings, filename: String) -> [Chapter] {
        guard !text.isEmpty else { return [] }
        
        if settings.autoDetectChapters && !settings.chapterSeparator.isEmpty {
            // Split text by the chapter separator
            let components = text.components(separatedBy: settings.chapterSeparator)
            
            guard components.count > 1 else {
                // If separator is not found, treat the whole file as one chapter
                return [createChapter(title: filename, content: text)]
            }
            
            return components.compactMap { chunk in
                let trimmedChunk = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedChunk.isEmpty else { return nil }
                
                // The first line of the chunk is assumed to be the title
                let lines = trimmedChunk.components(separatedBy: .newlines)
                let title = lines.first?.trimmingCharacters(in: .whitespaces) ?? "Untitled Chapter"
                let content = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                return createChapter(title: title, content: content.isEmpty ? trimmedChunk : content)
            }
        } else {
            // If auto-detect is off, treat the whole file as a single chapter
            return [createChapter(title: filename, content: text)]
        }
    }
    
    private func createChapter(title: String, content: String) -> Chapter {
        // The chapter number will be assigned later by the ViewModel
        return Chapter(title: title, chapterNumber: 0, rawContent: content)
    }
}
