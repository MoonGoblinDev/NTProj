import SwiftUI
import SwiftData

struct ChapterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: TranslationProject
    
    @Binding var selectedChapterID: PersistentIdentifier?

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
                            HStack {
                                Text("Ch. \(chapter.chapterNumber): \(chapter.title)")
                                    .lineLimit(1)
                                Spacer()
                                Text(chapter.translationStatus.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            self.selectedChapterID == chapter.id ? Color.accentColor.opacity(0.25) : Color.clear
                        )
                    }
                    .onDelete(perform: deleteChapters)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func handleTap(on chapter: Chapter) {
        if self.selectedChapterID == chapter.id {
            print("Tapped the currently active chapter: \(chapter.title)")
        } else {
            self.selectedChapterID = chapter.id
        }
    }
    
    private func deleteChapters(at offsets: IndexSet) {
        for index in offsets {
            let chapterToDelete = sortedChapters[index]
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
    // A helper view to manage state for the preview
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        @State private var selectedChapterID: PersistentIdentifier?
        
        var body: some View {
            ChapterListView(project: projects.first!, selectedChapterID: $selectedChapterID)
        }
    }
    
    // Create an in-memory container and populate it
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    
    let project = TranslationProject(name: "Sample Project", sourceLanguage: "A", targetLanguage: "B")
    project.chapters = [
        Chapter(title: "Chapter 1", chapterNumber: 1, rawContent: "Content 1"),
        Chapter(title: "Chapter 2: The Sequel", chapterNumber: 2, rawContent: "Content 2")
    ]
    container.mainContext.insert(project)
    
    return Previewer()
        .modelContainer(container)
        .frame(width: 350, height: 400)
}

#Preview("Empty State") {
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        @State private var selectedChapterID: PersistentIdentifier?
        
        var body: some View {
            ChapterListView(project: projects.first!, selectedChapterID: $selectedChapterID)
        }
    }
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    let project = TranslationProject(name: "Empty Project", sourceLanguage: "A", targetLanguage: "B")
    container.mainContext.insert(project) // Insert a project with no chapters
    
    return Previewer()
        .modelContainer(container)
        .frame(width: 350, height: 400)
}
