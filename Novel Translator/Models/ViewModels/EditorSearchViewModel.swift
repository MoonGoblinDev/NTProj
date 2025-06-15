//
//  EditorSearchViewModel.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 16/06/25.
//

import SwiftUI

@MainActor
@Observable
class EditorSearchViewModel {
    var searchQuery: String = ""
    var searchResults: [NSRange] = []
    var currentResultIndex: Int?

    func updateSearch(in text: String) {
        guard !searchQuery.isEmpty else {
            clearSearch()
            return
        }
        
        do {
            // Using caseInsensitive by default as it's the most common use case.
            let regex = try NSRegularExpression(pattern: searchQuery, options: .caseInsensitive)
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            searchResults = matches.map { $0.range }
            
            if !searchResults.isEmpty {
                currentResultIndex = 0
            } else {
                currentResultIndex = nil
            }
        } catch {
            clearSearch()
        }
    }
    
    func findNext() {
        guard let currentIndex = currentResultIndex, !searchResults.isEmpty else { return }
        currentResultIndex = (currentIndex + 1) % searchResults.count
    }

    func findPrevious() {
        guard let currentIndex = currentResultIndex, !searchResults.isEmpty else { return }
        currentResultIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
    }
    
    func clearSearch() {
        searchResults = []
        currentResultIndex = nil
    }
}
