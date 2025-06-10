//
//  GlossaryMatcher.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

class GlossaryMatcher {
    func detectTerms(in text: String, from glossary: [GlossaryEntry]) -> [GlossaryMatch] {
        var matches: [GlossaryMatch] = []
        
        // This is a simplified implementation. A real implementation would use
        // more efficient algorithms like Aho-Corasick for exact matching and
        // something like Levenshtein distance for fuzzy matching.
        
        for entry in glossary where entry.isActive {
            let termsToSearch = [entry.originalTerm] + entry.aliases
            
            for term in termsToSearch {
                var searchStartIndex = text.startIndex
                while searchStartIndex < text.endIndex,
                      let range = text.range(of: term, options: .caseInsensitive, range: searchStartIndex..<text.endIndex) {
                    let match = GlossaryMatch(
                        entry: entry,
                        range: range,
                        matchedAlias: term == entry.originalTerm ? nil : term
                    )
                    matches.append(match)
                    searchStartIndex = range.upperBound
                }
            }
        }
        
        // TODO: Add fuzzy matching, context awareness, and frequency tracking
        
        // For now, return unique entries to avoid multiple matches of the same entry
        let uniqueEntries = Dictionary(grouping: matches, by: { $0.entry.id })
        let firstMatchPerEntry = uniqueEntries.compactMap { $0.value.first }
        
        return firstMatchPerEntry
    }
}
