import SwiftUI
import SwiftData

struct TranslationWorkspaceView: View {
    @Binding var selectedChapterID: PersistentIdentifier?
    @Query private var chapters: [Chapter]
    
    let projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    
    @State private var isCreatingProject = false
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TranslationViewModel!

    private var chapter: Chapter? {
        chapters.first
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
                Button("Translate", systemImage: "sparkles") {
                    Task {
                        await viewModel.streamTranslateChapter(chapter)
                    }
                }
                .disabled(chapter == nil || chapter?.rawContent.isEmpty == true || viewModel?.isTranslating == true)
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            CreateProjectView()
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranslationViewModel(modelContext: modelContext)
            }
            viewModel.setChapter(chapter)
        }
        .onChange(of: chapter?.id) {
            viewModel.setChapter(chapter)
        }
        .alert("Translation Error", isPresented: .constant(viewModel?.errorMessage != nil), actions: {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel?.errorMessage ?? "An unknown error occurred.")
        })
    }

    @ViewBuilder
    private var editorOrPlaceholder: some View {
        if let chapter = self.chapter, self.viewModel != nil {
            TranslationEditorView(
                chapter: chapter,
                translatedContent: Binding(
                    get: { self.viewModel?.translationText ?? "" },
                    set: { self.viewModel?.translationText = $0 }
                ),
                isDisabled: viewModel?.isTranslating ?? false
            )
        } else {
            ContentUnavailableView(
                "No Chapter Selected",
                systemImage: "text.book.closed",
                description: Text("Select a chapter from the list in the sidebar.")
            )
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .padding()
            .background(.regularMaterial, in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding()
            .transition(.opacity.animation(.easeInOut))
    }
}
