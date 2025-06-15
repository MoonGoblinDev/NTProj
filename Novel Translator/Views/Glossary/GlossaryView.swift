import SwiftUI

struct GlossaryView: View {
    @ObservedObject var project: TranslationProject
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var entryToEdit: GlossaryEntry?
    
    private var sortedEntries: [GlossaryEntry] {
        project.glossaryEntries.sorted { $0.originalTerm.lowercased() < $1.originalTerm.lowercased() }
    }

    var body: some View {
        VStack {
            if sortedEntries.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Empty Glossary",
                    systemImage: "text.book.closed",
                    description: Text("Add terms using the '+' button below\nto ensure translation consistency.")
                )
                .multilineTextAlignment(.center)
                Spacer()
            } else {
                List {
                    ForEach(sortedEntries) { entry in
                        Button(action: {
                            self.entryToEdit = entry
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.originalTerm)
                                        .fontWeight(.bold)
                                    Text(entry.translation)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.category.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(entry.category.highlightColor.opacity(0.2), in: Capsule())
                            }
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $entryToEdit) { entry in
            // Find the index of the entry to create a binding to it.
            if let index = project.glossaryEntries.firstIndex(where: { $0.id == entry.id }) {
                GlossaryDetailView(entry: $project.glossaryEntries[index], project: project, isCreating: false)
                    .environmentObject(projectManager)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sortedEntries[$0].id }
        project.glossaryEntries.removeAll { idsToDelete.contains($0.id) }
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
}
