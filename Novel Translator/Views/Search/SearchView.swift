// ...
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
    
    // Debouncing
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    
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
                        .onSubmit(performSearch) // Search immediately on Enter
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
                    Button(action: replaceAll) {
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
                                HStack {
                                    Button(action: { navigateTo(result: result) }) {
                                        HStack(alignment: .top) {
                                            Text("\(result.lineNumber):")
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                            
                                            highlightedText(for: result)
                                                .lineLimit(2)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if isReplaceSectionExpanded {
                                        Spacer()
                                        Button("􀅌") {
                                            
                                            replace(result: result)
                                        }
                                        .buttonStyle(.bordered)
                                        .padding(.trailing, 4)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: searchQuery) { _, _ in debounceSearch() }
        .onChange(of: matchCase) { _, _ in debounceSearch() }
        .onChange(of: wholeWord) { _, _ in debounceSearch() }
        .onChange(of: useRegex) { _, _ in debounceSearch() }
    }
    
    private func debounceSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                performSearch()
            } catch is CancellationError {
                // Task was cancelled, which is expected.
            } catch {
                print("Search debounce task failed: \(error)")
            }
        }
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
    
    private func replace(result: SearchResultItem) {
        do {
            // 1. Perform the replacement in the editor state
            try workspaceViewModel.replace(searchResult: result, with: replaceQuery)
            // 2. Commit the changes from editor state back to the project model
            try workspaceViewModel.updateChapterFromState(id: result.chapterID)
            // 3. Refresh search results, which now read from the updated model
            performSearch()
        } catch {
            // TODO: Show an alert for the error
            print("Failed to replace item: \(error)")
        }
    }

    private func replaceAll() {
        let allChapterResults = searchResults.flatMap { $0.results }
        let groupedByChapter = Dictionary(grouping: allChapterResults) { $0.chapterID }

        do {
            for (chapterID, resultsInChapter) in groupedByChapter {
                let groupedByEditor = Dictionary(grouping: resultsInChapter) { $0.editorType }
                
                for (editorType, editorResults) in groupedByEditor {
                    try workspaceViewModel.replaceAll(
                        in: chapterID,
                        editorType: editorType,
                        with: replaceQuery,
                        from: editorResults
                    )
                }
                // After all replacements in a chapter's state are done, commit to the model.
                try workspaceViewModel.updateChapterFromState(id: chapterID)
            }
            
            // After all chapters are updated, refresh the search to update the UI.
            performSearch()
        } catch {
            // TODO: Show an alert for the error
            print("Failed to replace all: \(error)")
        }
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


#Preview {
    let mocks = PreviewMocks.shared
    return SearchView(project: mocks.project)
        .environmentObject(mocks.workspaceViewModel)
        .environmentObject(mocks.appContext)
        .frame(width: 380, height: 700)
}
