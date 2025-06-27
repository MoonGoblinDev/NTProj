import SwiftUI

struct ChapterListView: View {
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    @ObservedObject var project: TranslationProject
    
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
                                        .foregroundColor(workspaceViewModel.editorStates[chapter.id]?.hasUnsavedChanges ?? false ? Color.unsaved : .primary)
                                    Text(chapter.title)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Text("\(chapter.translatedLineCount) / \(chapter.sourceLineCount)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(lineCountColor(for: chapter))
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
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
    
    private func lineCountColor(for chapter: Chapter) -> Color {
        // if translation count = 0, make it gray
        if chapter.translatedLineCount == 0 {
            return .secondary
        }
        // if translation count > source count make color red
        if chapter.translatedLineCount > chapter.sourceLineCount {
            return .red
        }
        // if translation < count make color yellow
        if chapter.translatedLineCount < chapter.sourceLineCount {
            return .orange // Using orange for better visibility than yellow
        }
        // if same make it green
        if chapter.translatedLineCount == chapter.sourceLineCount {
            return .green
        }
        // Fallback
        return .secondary
    }
    
    private func rowBackground(for chapterID: UUID) -> some View {
        if workspaceViewModel.activeChapterID == chapterID {
            return Color.accentColor.opacity(0.25)
        } else if workspaceViewModel.openChapterIDs.contains(chapterID) {
            return Color.secondary.opacity(0.15)
        } else {
            return Color.clear
        }
    }
    
    private func handleTap(on chapter: Chapter) {
        workspaceViewModel.openChapter(id: chapter.id)
    }
    
    private func deleteChapters(at offsets: IndexSet) {
        let chapterIDsToDelete = offsets.map { sortedChapters[$0].id }
        
        for id in chapterIDsToDelete {
            workspaceViewModel.closeChapter(id: id)
            project.chapters.removeAll { $0.id == id }
        }
    }
}
