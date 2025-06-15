//
//  SearchView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 15/06/25.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject private var appContext: AppContext

    @ObservedObject var project: TranslationProject
    
    // Search state
    @State private var searchQuery: String = ""
    @State private var matchCase: Bool = false
    @State private var wholeWord: Bool = false
    @State private var useRegex: Bool = false
    
    // Replace state
    @State private var replaceQuery: String = ""
    @State private var isReplaceSectionExpanded: Bool = false
    
    // Results
    @State private var searchResults: [SearchResultGroup] = []
    @State private var isSearching: Bool = false
    
    private let searchService = SearchService()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Input
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(isReplaceSectionExpanded ? .degrees(90) : .zero)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isReplaceSectionExpanded.toggle()
                            }
                        }

                    TextField("Search", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit(performSearch)
                }
                
                if isReplaceSectionExpanded {
                    TextField("Replace", text: $replaceQuery)
                        .textFieldStyle(.plain)
                        .padding(.leading, 18)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // MARK: - Search Controls
            HStack {
                Spacer()
                
                SearchOptionButton(label: "Aa", help: "Match Case", isOn: $matchCase)
                SearchOptionButton(label: "A-Z", help: "Match Whole Word", isOn: $wholeWord)
                SearchOptionButton(label: ".*", help: "Use Regular Expression", isOn: $useRegex)

                if isReplaceSectionExpanded {
                    Button(action: {}) { // TODO: Implement Replace All
                        Image(systemName: "arrow.2.squarepath")
                    }
                    .buttonStyle(.plain)
                    .help("Replace All")
                    .disabled(replaceQuery.isEmpty || searchResults.isEmpty)
                }
            }
            .padding(.horizontal)
            
            Divider().padding(.top, 8)

            // MARK: - Search Results
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxHeight: .infinity)
            } else if !searchQuery.isEmpty && searchResults.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(searchResults) { group in
                        Section(header: Text(group.chapterTitle).lineLimit(1)) {
                            ForEach(group.results) { result in
                                Button(action: { navigateTo(result: result) }) {
                                    HStack(alignment: .top) {
                                        Text("\(result.lineNumber):")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        
                                        highlightedText(for: result)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: searchQuery) { _, _ in performSearch() }
        .onChange(of: matchCase) { _, _ in performSearch() }
        .onChange(of: wholeWord) { _, _ in performSearch() }
        .onChange(of: useRegex) { _, _ in performSearch() }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            let options = SearchOptions(matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
            let results = await searchService.search(in: project, query: searchQuery, options: options)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    private func navigateTo(result: SearchResultItem) {
        // Use the AppContext to coordinate navigation.
        appContext.searchResultToHighlight = result
    }
    
    private func highlightedText(for result: SearchResultItem) -> Text {
        // Create an AttributedString from the full line of text.
        var attributedString = AttributedString(result.lineContent)
        
        // Safely find the range of the match within the attributed string.
        if let range = Range(result.matchRangeInLine, in: attributedString) {
            // Apply styling attributes to that specific range.
            attributedString[range].font = .body.bold()
            attributedString[range].backgroundColor = Color.accentColor.opacity(0.3)
        }
        
        // Return a single Text view created from the now-styled AttributedString.
        // This preserves text flow and layout behavior.
        return Text(attributedString)
    }
}

fileprivate struct SearchOptionButton: View {
    let label: String
    let help: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .padding(.horizontal, 6)
                .background(isOn ? Color.accentColor.opacity(0.5) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
