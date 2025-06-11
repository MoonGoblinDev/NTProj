import SwiftUI
import SwiftData

struct GlossaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: TranslationProject

    @State private var entryToEdit: GlossaryEntry?
    @State private var isSheetPresented = false
    
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
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Edit") {
                                entryToEdit = entry
                                isSheetPresented = true
                            }
                            Button("Delete", role: .destructive) {
                                delete(entry: entry)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $isSheetPresented, onDismiss: { entryToEdit = nil }) {
            // This sheet is for editing an existing entry
            if let entryToEdit {
                GlossaryDetailView(entry: entryToEdit, project: project)
            }
        }
    }

    private func delete(entry: GlossaryEntry) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete glossary entry: \(error)")
        }
    }
}
