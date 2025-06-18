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
    let absoluteMatchRange: NSRange // The range of the match within the full text document

    enum EditorType: String, Codable {
        case source, translated
    }

    // Explicit conformance because NSRange is not Hashable
    static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(chapterID)
        hasher.combine(editorType)
        hasher.combine(lineNumber)
        hasher.combine(lineContent)
        hasher.combine(matchRangeInLine.location)
        hasher.combine(matchRangeInLine.length)
        hasher.combine(absoluteMatchRange.location)
        hasher.combine(absoluteMatchRange.length)
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
            if !chapter.rawContent.isEmpty {
                let sourceMatches = findMatchesInFullText(in: chapter.rawContent, for: query, with: options)
                for match in sourceMatches {
                    chapterResults.append(
                        SearchResultItem(
                            chapterID: chapter.id,
                            editorType: .source,
                            lineNumber: match.lineNumber,
                            lineContent: match.lineContent,
                            matchRangeInLine: match.matchRangeInLine,
                            absoluteMatchRange: match.absoluteMatchRange
                        )
                    )
                }
            }
            
            // Search in translated content
            if let translatedContent = chapter.translatedContent, !translatedContent.isEmpty {
                let translatedMatches = findMatchesInFullText(in: translatedContent, for: query, with: options)
                for match in translatedMatches {
                    chapterResults.append(
                        SearchResultItem(
                            chapterID: chapter.id,
                            editorType: .translated,
                            lineNumber: match.lineNumber,
                            lineContent: match.lineContent,
                            matchRangeInLine: match.matchRangeInLine,
                            absoluteMatchRange: match.absoluteMatchRange
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
    
    /// Finds all occurrences of a query in a multi-line string, returning both line-relative and absolute ranges.
    private func findMatchesInFullText(in text: String, for query: String, with options: SearchOptions) -> [(lineContent: String, lineNumber: Int, matchRangeInLine: NSRange, absoluteMatchRange: NSRange)] {
        var results: [(String, Int, NSRange, NSRange)] = []
        guard !text.isEmpty, !query.isEmpty else { return [] }

        // 1. Create the regex for finding the query in the whole text
        let searchPattern: String
        if options.useRegex {
            searchPattern = query
        } else if options.wholeWord {
            // Use word boundaries for whole word search
            searchPattern = "\\b\(NSRegularExpression.escapedPattern(for: query))\\b"
        } else {
            searchPattern = NSRegularExpression.escapedPattern(for: query)
        }

        var regexOptions: NSRegularExpression.Options = []
        if !options.matchCase {
            regexOptions.insert(.caseInsensitive)
        }
        
        guard let regex = try? NSRegularExpression(pattern: searchPattern, options: regexOptions) else {
            return []
        }

        // 2. Find all matches in the full text
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let allMatches = regex.matches(in: text, range: fullRange)
        
        guard !allMatches.isEmpty else { return [] }

        // 3. For each match, find its line number and content.
        // To do this efficiently, pre-calculate the start-and-end range of each line.
        var lineRanges: [NSRange] = []
        // *** THIS IS THE FIX ***
        (text as NSString).enumerateSubstrings(in: fullRange, options: .byLines) { (_, substringRange, _, _) in
            lineRanges.append(substringRange)
        }
        
        // 4. Create result items
        for match in allMatches {
            let absoluteMatchRange = match.range
            
            // Find which line this match belongs to by checking for range intersection
            if let lineIndex = lineRanges.firstIndex(where: { NSIntersectionRange($0, absoluteMatchRange).length > 0 }) {
                let lineRange = lineRanges[lineIndex]
                let lineContent = (text as NSString).substring(with: lineRange)
                let lineNumber = lineIndex + 1
                
                // Calculate the match's range relative to the start of its line
                let matchRangeInLine = NSRange(
                    location: absoluteMatchRange.location - lineRange.location,
                    length: absoluteMatchRange.length
                )
                
                results.append((lineContent, lineNumber, matchRangeInLine, absoluteMatchRange))
            }
        }
        
        return results
    }
}
