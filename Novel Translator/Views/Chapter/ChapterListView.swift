import SwiftUI


fileprivate struct ChapterListItemView: View {
    let chapter: Chapter
    let isActive: Bool
    let isOpen: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text("#\(chapter.chapterNumber)   ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("􁜿 ")
                        .lineLimit(1)
                        .foregroundColor(hasUnsavedChanges ? .unsaved : .primary)
                    Text(chapter.title)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("\(chapter.translatedLineCount) / \(chapter.sourceLineCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(lineCountColor)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground)
    }

    private var rowBackground: some View {
        if isActive {
            return Color.accentColor.opacity(0.25)
        } else if isOpen {
            return Color.secondary.opacity(0.15)
        } else {
            return Color.clear
        }
    }

    private var lineCountColor: Color {
        if chapter.translatedLineCount == 0 { return .secondary }
        if chapter.translatedLineCount > chapter.sourceLineCount { return .red }
        if chapter.translatedLineCount < chapter.sourceLineCount { return .orange }
        if chapter.translatedLineCount == chapter.sourceLineCount { return .green }
        return .secondary
    }
}


// MODIFIED: The main list view is now responsible for calculating state for each item.
struct ChapterListView: View {
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @ObservedObject var project: TranslationProject
    
    // The sorted chapter list is managed in @State to prevent re-sorting on every render.
    @State private var sortedChapters: [Chapter] = []
    
    var body: some View {
        VStack(spacing: 0) {
            if sortedChapters.isEmpty {
                ContentUnavailableView(
                    "No Chapters",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Import your first chapter to begin.")
                )
                .frame(maxHeight: .infinity)
            } else {
                // The List now uses an explicit ID for better performance
                List {
                    // ForEach now calculates state and passes simple values to the item view.
                    // This is the core of the performance optimization.
                    ForEach(sortedChapters) { chapter in
                        ChapterListItemView(
                            chapter: chapter,
                            isActive: workspaceViewModel.activeChapterID == chapter.id,
                            isOpen: workspaceViewModel.openChapterIDs.contains(chapter.id),
                            hasUnsavedChanges: workspaceViewModel.editorStates[chapter.id]?.hasUnsavedChanges ?? false,
                            onSelect: {
                                workspaceViewModel.openChapter(id: chapter.id)
                            }
                        )
                        // By giving each view a stable identity, we help SwiftUI avoid re-rendering.
                        .id(chapter.id)
                    }
                    .onDelete(perform: deleteChapters)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            // Sort the chapters once when the view appears.
            sortedChapters = project.chapters.sorted { $0.chapterNumber < $1.chapterNumber }
        }
        .onChange(of: project.chapters) {
            // Re-sort the list only when the underlying chapter data actually changes
            // (e.g., import or deletion), not on every state change.
            sortedChapters = project.chapters.sorted { $0.chapterNumber < $1.chapterNumber }
        }
    }
    
    private func deleteChapters(at offsets: IndexSet) {
        let chapterIDsToDelete = offsets.map { sortedChapters[$0].id }
        
        for id in chapterIDsToDelete {
            // Closing the chapter first is good practice
            workspaceViewModel.closeChapter(id: id)
            // This mutation will trigger the .onChange(of: project.chapters) modifier.
            project.chapters.removeAll { $0.id == id }
        }
    }
}
