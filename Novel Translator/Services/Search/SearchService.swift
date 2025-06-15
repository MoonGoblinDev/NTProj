//
//  SearchService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 15/06/25.
//

import Foundation

struct SearchOptions {
    let matchCase: Bool
    let wholeWord: Bool
    let useRegex: Bool
}

// Represents a match within a single line of text
struct SearchResultItem: Identifiable, Hashable {
    let id = UUID()
    let chapterID: UUID
    let editorType: EditorType // source or translated
    let lineNumber: Int
    let lineContent: String
    let matchRangeInLine: NSRange // The range of the match within its line
    
    enum EditorType: String, Codable {
        case source, translated
    }
}

// Groups all results for a specific chapter
struct SearchResultGroup: Identifiable {
    var id: UUID { chapterID }
    let chapterID: UUID
    let chapterTitle: String
    var results: [SearchResultItem]
}

class SearchService {
    
    func search(in project: TranslationProject, query: String, options: SearchOptions) async -> [SearchResultGroup] {
        guard !query.isEmpty else { return [] }
        
        var allResults: [SearchResultGroup] = []

        for chapter in project.chapters {
            var chapterResults: [SearchResultItem] = []
            
            // Search in raw content
            let sourceMatches = findMatches(in: chapter.rawContent, for: query, with: options)
            for match in sourceMatches {
                chapterResults.append(
                    SearchResultItem(
                        chapterID: chapter.id,
                        editorType: .source,
                        lineNumber: match.lineNumber,
                        lineContent: match.line,
                        matchRangeInLine: match.range
                    )
                )
            }
            
            // Search in translated content
            if let translatedContent = chapter.translatedContent {
                let translatedMatches = findMatches(in: translatedContent, for: query, with: options)
                for match in translatedMatches {
                    chapterResults.append(
                        SearchResultItem(
                            chapterID: chapter.id,
                            editorType: .translated,
                            lineNumber: match.lineNumber,
                            lineContent: match.line,
                            matchRangeInLine: match.range
                        )
                    )
                }
            }
            
            if !chapterResults.isEmpty {
                // Sort results by line number
                chapterResults.sort { $0.lineNumber < $1.lineNumber }
                let group = SearchResultGroup(chapterID: chapter.id, chapterTitle: chapter.title, results: chapterResults)
                allResults.append(group)
            }
        }
        
        return allResults.sorted { $0.chapterTitle < $1.chapterTitle }
    }
    
    /// Finds all occurrences of a query in a multi-line string.
    func findMatches(in text: String, for query: String, with options: SearchOptions) -> [(line: String, lineNumber: Int, range: NSRange)] {
        var results: [(String, Int, NSRange)] = []
        let lines = text.components(separatedBy: .newlines)
        
        let searchPattern: String
        if options.useRegex {
            searchPattern = query
        } else if options.wholeWord {
            searchPattern = "\\b\(NSRegularExpression.escapedPattern(for: query))\\b"
        } else {
            searchPattern = NSRegularExpression.escapedPattern(for: query)
        }
        
        var regexOptions: NSRegularExpression.Options = [.anchorsMatchLines]
        if !options.matchCase {
            regexOptions.insert(.caseInsensitive)
        }
        
        guard let regex = try? NSRegularExpression(pattern: searchPattern, options: regexOptions) else {
            return []
        }
        
        for (index, line) in lines.enumerated() {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                results.append((line, index + 1, match.range))
            }
        }
        
        return results
    }
}
