import SwiftUI
import SwiftData

struct GlossaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: TranslationProject

    // This state variable will hold the entry we want to edit.
    // When it's not nil, the sheet will be presented.
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
                        // THE CHANGE: Wrap the row content in a Button.
                        Button(action: {
                            // When clicked, set the entryToEdit state.
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
                                    .background(Color.secondary.opacity(0.2), in: Capsule())
                            }
                            // Make the button content use the primary text color.
                            .foregroundStyle(.primary)
                        }
                        // Use .plain button style to make it look like a normal list row.
                        .buttonStyle(.plain)
                    }
                    // We can add swipe-to-delete as a fast deletion method.
                    .onDelete(perform: delete)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        // This .sheet modifier is now triggered when entryToEdit is not nil.
        .sheet(item: $entryToEdit) { entry in
            // When the sheet is presented, pass the selected entry to the detail view.
            GlossaryDetailView(entry: entry, project: project)
        }
    }

    /// This function handles deletion, either from the onDelete modifier or a future delete button.
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
