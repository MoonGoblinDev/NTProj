import SwiftUI
import SwiftData
import STTextViewSwiftUI

struct TranslationWorkspaceView: View {
    @EnvironmentObject private var appContext: AppContext
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedChapterID: PersistentIdentifier?
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    @State private var chapter: Chapter?
    
    @State private var isCreatingProject = false
    @State private var viewModel: TranslationViewModel!
    
    @State private var sourceAttributedText: AttributedString = ""
    @State private var translatedAttributedText: AttributedString = ""
    
    @State private var sourceSelection: NSRange?
    @State private var translatedSelection: NSRange?
    
    @State private var entryToDisplay: GlossaryEntry?
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    private let glossaryMatcher = GlossaryMatcher()
    
    private var project: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
    init(selectedChapterID: Binding<PersistentIdentifier?>, projects: [TranslationProject], selectedProjectID: Binding<PersistentIdentifier?>) {
        _selectedChapterID = selectedChapterID
        self.projects = projects
        _selectedProjectID = selectedProjectID
    }

    var body: some View {
        ZStack {
            editorOrPlaceholder
            
            if viewModel?.isTranslating == true {
                loadingOverlay
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                ProjectSelectorView(
                    projects: projects,
                    selectedProjectID: $selectedProjectID,
                    onAddProject: { isCreatingProject = true }
                )
                .frame(minWidth: 200, idealWidth: 250)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save", systemImage: "square.and.arrow.down") {
                    saveChanges()
                }
                .disabled(chapter == nil || viewModel.isTranslating)
                
                Button("Translate", systemImage: "sparkles") {
                    Task {
                        await viewModel.streamTranslateChapter(chapter)
                    }
                }
                .disabled(chapter == nil || chapter?.rawContent.isEmpty == true || viewModel?.isTranslating == true)
            }
        }
        .sheet(isPresented: $isCreatingProject) { CreateProjectView() }
        .sheet(isPresented: $appContext.isSheetPresented, onDismiss: { appContext.glossaryEntryToEditID = nil }) {
            if let entry = entryToDisplay, let project = self.project {
                NavigationStack {
                    GlossaryDetailView(entry: entry, project: project)
                }
            } else {
                Text("Error: Could not find glossary item.").padding()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel(modelContext: modelContext)
            }
            updateChapter(from: selectedChapterID)
        }
        .onChange(of: selectedChapterID) { _, newID in
            updateChapter(from: newID)
        }
        .onChange(of: viewModel?.translationText) { _, newText in
            if let text = newText {
                setTranslatedText(text)
            }
        }
        .onChange(of: sourceSelection) { _, newSelection in
            handleSelectionChange(newSelection)
        }
        // **FIX #1:** Correctly compare the string content, not the debug description.
        .onChange(of: sourceAttributedText) { oldValue, newValue in
            if String(oldValue.characters) != String(newValue.characters) {
                 updateSourceHighlights()
            }
        }
        .onChange(of: appContext.glossaryEntryToEditID) { _, newID in
            guard let newID = newID else {
                entryToDisplay = nil
                return
            }
            if let foundEntry = project?.glossaryEntries.first(where: { $0.id == newID }) {
                self.entryToDisplay = foundEntry
            }
        }
        .alert("Translation Error", isPresented: .constant(viewModel?.errorMessage != nil), actions: {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel?.errorMessage ?? "An unknown error occurred.")
        })
    }
    
    @ViewBuilder private var editorOrPlaceholder: some View {
        if let chapter = self.chapter, self.viewModel != nil {
            TranslationEditorView(
                sourceText: $sourceAttributedText,
                translatedText: $translatedAttributedText,
                sourceSelection: $sourceSelection,
                translatedSelection: $translatedSelection,
                chapter: chapter,
                isDisabled: viewModel.isTranslating
            )
        } else {
            ContentUnavailableView(
                "No Chapter Selected",
                systemImage: "text.book.closed",
                description: Text("Select a chapter from the list in the sidebar.")
            )
        }
    }
    
    @ViewBuilder private var loadingOverlay: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .padding()
            .background(.regularMaterial, in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding()
            .transition(.opacity.animation(.easeInOut))
    }
    
    private func updateChapter(from id: PersistentIdentifier?) {
        guard let id = id else {
            self.chapter = nil
            sourceAttributedText = ""
            translatedAttributedText = ""
            sourceSelection = nil
            translatedSelection = nil
            return
        }
        
        let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.persistentModelID == id })
        if let chapterToLoad = try? modelContext.fetch(descriptor).first {
            self.chapter = chapterToLoad
            loadChapter(chapterToLoad)
        } else {
            self.chapter = nil
            sourceAttributedText = ""
            translatedAttributedText = ""
            sourceSelection = nil
            translatedSelection = nil
        }
    }
    
    private func saveChanges() {
        guard let chapter = self.chapter else { return }
        
        // **FIX #2:** Use `String(attributedString.characters)` to get the plain text.
        let rawContent = String(sourceAttributedText.characters)
        let translatedContent = String(translatedAttributedText.characters)
        
        let service = TranslationService(modelContext: modelContext)
        do {
            try service.saveManualChanges(
                for: chapter,
                rawContent: rawContent,
                translatedContent: translatedContent
            )
        } catch {
            viewModel.errorMessage = "Failed to save manual changes: \(error.localizedDescription)"
        }
    }
    
    private func loadChapter(_ chapterToLoad: Chapter) {
        sourceSelection = nil
        translatedSelection = nil
        
        sourceAttributedText = AttributedString(chapterToLoad.rawContent, attributes: getBaseAttributes())
        
        viewModel.setChapter(chapterToLoad)
        setTranslatedText(viewModel.translationText)
    }
    
    private func handleSelectionChange(_ selection: NSRange?) {
        guard let selection, selection.length == 0 else { return }
        // Using .description here is acceptable as it's for range calculation, not content.
        if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: sourceAttributedText.description)) }) {
            appContext.glossaryEntryToEditID = match.entry.id
        }
    }
    
    private func getBaseAttributes() -> AttributeContainer {
        var container = AttributeContainer()
        container.foregroundColor = NSColor.textColor
        container.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        return container
    }
    
    private func setTranslatedText(_ text: String) {
        self.translatedAttributedText = AttributedString(text, attributes: getBaseAttributes())
    }

    private func updateSourceHighlights() {
        guard let project = project, !sourceAttributedText.description.isEmpty else {
            self.glossaryMatches = []
            return
        }
        
        let stringToMatch = String(sourceAttributedText.characters)
        let fullNSRange = NSRange(location: 0, length: stringToMatch.utf16.count)
        
        guard let fullRange = Range(fullNSRange, in: sourceAttributedText) else { return }
        
        sourceAttributedText[fullRange].foregroundColor = NSColor.textColor
        sourceAttributedText[fullRange].underlineStyle = nil
        sourceAttributedText[fullRange].link = nil

        self.glossaryMatches = glossaryMatcher.detectTerms(in: stringToMatch, from: project.glossaryEntries)

        var highlightContainer = AttributeContainer()
        highlightContainer.underlineStyle = .single
        highlightContainer.foregroundColor = NSColor(Color.gold)
        
        for match in glossaryMatches {
            if let range = Range(match.range, in: sourceAttributedText) {
                sourceAttributedText[range].mergeAttributes(highlightContainer, mergePolicy: .keepNew)
            }
        }
    }
}

extension Range where Bound == String.Index {
    func toNSRange(in string: String) -> NSRange {
        return NSRange(self, in: string)
    }
}
