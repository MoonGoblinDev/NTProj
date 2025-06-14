import SwiftUI
import SwiftData

struct ChapterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkspaceViewModel.self) private var workspaceViewModel
    @Bindable var project: TranslationProject
    
    @State private var isImporterPresented = false
    
    private var sortedChapters: [Chapter] {
        project.chapters.sorted { $0.chapterNumber < $1.chapterNumber }
    }
    
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
                List {
                    ForEach(sortedChapters) { chapter in
                        Button(action: {
                            handleTap(on: chapter)
                        }) {
                            HStack(spacing: 8) {
                                HStack(spacing: 0){
                                    Text("#\(chapter.chapterNumber)   ")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("􁜿 ")
                                        .lineLimit(1)
                                        .foregroundColor(workspaceViewModel.editorStates[chapter.id]?.hasUnsavedChanges ?? false ? Color.unsaved : .white)
                                    Text(chapter.title)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Text(chapter.translationStatus.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle()) // Add this line
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(rowBackground(for: chapter.id))
                    }
                    .onDelete(perform: deleteChapters)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func rowBackground(for chapterID: PersistentIdentifier) -> some View {
        if workspaceViewModel.activeChapterID == chapterID {
            return Color.accentColor.opacity(0.25)
        } else if workspaceViewModel.openChapterIDs.contains(chapterID) {
            return Color.secondary.opacity(0.15)
        } else {
            return Color.clear
        }
    }
    
    private func handleTap(on chapter: Chapter) {
        workspaceViewModel.openChapter(id: chapter.persistentModelID)
    }
    
    private func deleteChapters(at offsets: IndexSet) {
        for index in offsets {
            let chapterToDelete = sortedChapters[index]
            workspaceViewModel.closeChapter(id: chapterToDelete.persistentModelID)
            modelContext.delete(chapterToDelete)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete chapter: \(error.localizedDescription)")
        }
    }
}

#Preview("With Chapters") {
    // ... Previews would need to be updated to provide WorkspaceViewModel ...
    // For brevity, previews are omitted from this change.
    Text("Chapter List Preview")
}

#Preview("Empty State") {
    Text("Chapter List Preview")
}
