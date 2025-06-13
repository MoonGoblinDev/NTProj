import SwiftUI
import SwiftData
import STTextViewSwiftUI

struct TranslationWorkspaceView: View {
    @EnvironmentObject private var appContext: AppContext
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedChapterID: PersistentIdentifier?
    @Query private var chapters: [Chapter]
    
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    @State private var isCreatingProject = false
    @State private var viewModel: TranslationViewModel!
    
    @State private var sourceAttributedText: AttributedString = ""
    @State private var translatedAttributedText: AttributedString = ""
    
    @State private var sourceSelection: NSRange?
    
    @State private var entryToDisplay: GlossaryEntry?
    @State private var glossaryMatches: [GlossaryMatch] = []
    
    private let glossaryMatcher = GlossaryMatcher()
    
    private var chapter: Chapter? { chapters.first }
    private var project: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
    init(selectedChapterID: Binding<PersistentIdentifier?>, projects: [TranslationProject], selectedProjectID: Binding<PersistentIdentifier?>) {
        _selectedChapterID = selectedChapterID
        self.projects = projects
        _selectedProjectID = selectedProjectID
        
        let id = selectedChapterID.wrappedValue
        let predicate = id.map { finalID in
            #Predicate<Chapter> { $0.persistentModelID == finalID }
        } ?? #Predicate<Chapter> { _ in false }
        
        _chapters = Query(filter: predicate)
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
                .disabled(chapter == nil)
                
                Button("Translate", systemImage: "sparkles") {
                    Task {
                        await viewModel.streamTranslateChapter(chapter)
                        setTranslatedText(viewModel.translationText)
                    }
                }
                .disabled(chapter == nil || chapter?.rawContent.isEmpty == true || viewModel?.isTranslating == true)
            }
        }
        .sheet(isPresented: $isCreatingProject) { CreateProjectView() }
        .sheet(isPresented: $appContext.isSheetPresented, onDismiss: { appContext.glossaryEntryToEditID = nil }) {
            if let entry = entryToDisplay, let project = self.project {
                GlossaryDetailView(entry: entry, project: project)
            } else {
                Text("Error: Could not find glossary item.").padding()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel(modelContext: modelContext)
            }
            // Load the initially selected chapter, if any
            if let chapter = self.chapter {
                loadChapter(chapter)
            }
        }
        .onChange(of: selectedChapterID) { _, newID in
            // This is now the single source of truth for loading a new chapter.
            guard let newID = newID else {
                // If selection is cleared, clear the editors.
                sourceAttributedText = ""
                translatedAttributedText = ""
                return
            }
            
            // Manually fetch the chapter to avoid race conditions with the @Query.
            let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.persistentModelID == newID })
            if let chapterToLoad = try? modelContext.fetch(descriptor).first {
                loadChapter(chapterToLoad)
            }
        }
        .onChange(of: sourceSelection) { _, newSelection in
            handleSelectionChange(newSelection)
        }
        .onChange(of: sourceAttributedText) { oldValue, newValue in
            if oldValue.description != newValue.description {
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

    
    @ViewBuilder private var editorOrPlaceholder: some View { if let chapter = self.chapter, self.viewModel != nil { TranslationEditorView(sourceText: $sourceAttributedText, translatedText: $translatedAttributedText, sourceSelection: $sourceSelection, translatedSelection: .constant(nil), chapter: chapter, isDisabled: viewModel.isTranslating) } else { ContentUnavailableView("No Chapter Selected", systemImage: "text.book.closed", description: Text("Select a chapter from the list in the sidebar.")) } }
    
    @ViewBuilder private var loadingOverlay: some View { ProgressView().progressViewStyle(.circular).padding().background(.regularMaterial, in: Circle()).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding().transition(.opacity.animation(.easeInOut)) }
    
    private func saveChanges() { guard let chapter = chapter else { return }; let newRawContent = sourceAttributedText.description; let newTranslatedContent = translatedAttributedText.description; var hasChanges = false; if chapter.rawContent != newRawContent { chapter.rawContent = newRawContent; hasChanges = true }; if chapter.translatedContent ?? "" != newTranslatedContent { chapter.translatedContent = newTranslatedContent; hasChanges = true }; if hasChanges { chapter.project?.lastModifiedDate = Date(); do { try modelContext.save(); print("Changes saved successfully.") } catch { print("Failed to save changes: \(error)") } } }
    
    private func handleSelectionChange(_ selection: NSRange?) { guard let selection, selection.length == 0 else { return }; if let match = glossaryMatches.first(where: { NSLocationInRange(selection.location, $0.range.toNSRange(in: sourceAttributedText.description)) }) { appContext.glossaryEntryToEditID = match.entry.id } }
    
    private func getBaseAttributes() -> AttributeContainer { var container = AttributeContainer(); container.foregroundColor = NSColor.textColor; container.font = NSFont.systemFont(ofSize: 14, weight: .regular); return container }
    
    private func setTranslatedText(_ text: String) { self.translatedAttributedText = AttributedString(text, attributes: getBaseAttributes()) }

    /// A dedicated function to load content from a specific chapter object.
    private func loadChapter(_ chapterToLoad: Chapter) {
        // Set the source text from the guaranteed correct chapter.
        sourceAttributedText = AttributedString(chapterToLoad.rawContent, attributes: getBaseAttributes())
        
        // Update the view model and translated text.
        viewModel.setChapter(chapterToLoad)
        setTranslatedText(viewModel.translationText)
        
        // Highlights will be applied automatically by the .onChange(of: sourceAttributedText) modifier.
    }

    /// Applies highlights to the source text. (This function is now correct, but the calling logic was flawed).
    private func updateSourceHighlights() {
        guard let project = project, !sourceAttributedText.description.isEmpty else { return }
        
        let stringToMatch = sourceAttributedText.description
        let fullNSRange = NSRange(location: 0, length: stringToMatch.count)
        
        guard let fullRange = Range(fullNSRange, in: sourceAttributedText) else { return }
        
        // Clear previous highlights
        sourceAttributedText[fullRange].underlineStyle = nil
        sourceAttributedText[fullRange].foregroundColor = NSColor.textColor

        // Find and apply new highlights
        self.glossaryMatches = glossaryMatcher.detectTerms(in: stringToMatch, from: project.glossaryEntries)

        var highlightContainer = AttributeContainer()
        highlightContainer.underlineStyle = .single
        highlightContainer.foregroundColor = .gold
        
        for match in glossaryMatches {
            if let range = Range(match.range, in: sourceAttributedText) {
                sourceAttributedText[range].mergeAttributes(highlightContainer, mergePolicy: .keepNew)
            }
        }
    }
}




extension Range where Bound == String.Index {
    func toNSRange(in string: String) -> NSRange { return NSRange(self, in: string) }
}
