import Foundation

class GlossaryMatcher {
    func detectTerms(in text: String, from glossary: [GlossaryEntry]) -> [GlossaryMatch] {
        var matches: [GlossaryMatch] = []
        
        // This is a simplified implementation. A real implementation would use
        // more efficient algorithms like Aho-Corasick for exact matching and
        // something like Levenshtein distance for fuzzy matching.
        
        for entry in glossary where entry.isActive {
            // Include the original term and all its aliases in the search.
            let termsToSearch = [entry.originalTerm] + entry.aliases.filter { !$0.isEmpty }
            
            for term in termsToSearch {
                guard !term.isEmpty else { continue }
                var searchStartIndex = text.startIndex
                
                // Find all occurrences of the term in the text.
                while searchStartIndex < text.endIndex,
                      let range = text.range(of: term, options: .caseInsensitive, range: searchStartIndex..<text.endIndex) {
                    let match = GlossaryMatch(
                        entry: entry,
                        range: range,
                        matchedAlias: term.lowercased() == entry.originalTerm.lowercased() ? nil : term
                    )
                    matches.append(match)
                    searchStartIndex = range.upperBound
                }
            }
        }
        
        // Return all found matches, sorted by their position in the text.
        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
    
    func detectTranslations(in text: String, from glossary: [GlossaryEntry]) -> [GlossaryMatch] {
        var matches: [GlossaryMatch] = []
        
        for entry in glossary where entry.isActive && !entry.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let termToSearch = entry.translation
            
            var searchStartIndex = text.startIndex
            
            // Find all occurrences of the term in the text.
            while searchStartIndex < text.endIndex,
                  let range = text.range(of: termToSearch, options: .caseInsensitive, range: searchStartIndex..<text.endIndex) {
                let match = GlossaryMatch(
                    entry: entry,
                    range: range,
                    matchedAlias: nil // No aliases for translations
                )
                matches.append(match)
                searchStartIndex = range.upperBound
            }
        }
        
        // Return all found matches, sorted by their position in the text.
        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}
