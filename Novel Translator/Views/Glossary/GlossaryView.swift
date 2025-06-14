import SwiftUI
import SwiftData

struct GlossaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: TranslationProject

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
            GlossaryDetailView(entry: entry, project: project)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let entryToDelete = sortedEntries[index]
            modelContext.delete(entryToDelete)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete glossary entry: \(error)")
        }
    }
}
