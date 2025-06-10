import SwiftUI
import SwiftData

struct GlossaryView: View {
    @Bindable var project: TranslationProject

    var body: some View {
        VStack {
            if project.glossaryEntries.isEmpty {
                // --- FIX: MAKE IT EXPAND ---
                Spacer() // Pushes the content to the center vertically
                ContentUnavailableView(
                    "Empty Glossary",
                    systemImage: "text.book.closed",
                    description: Text("Add terms to ensure translation consistency.")
                )
                Spacer() // Balances the top spacer
            } else {
                List {
                    ForEach(project.glossaryEntries.sorted(by: { $0.originalTerm < $1.originalTerm })) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.originalTerm)
                                .fontWeight(.bold)
                            Text("\(entry.translation) [\(entry.category.displayName)]")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
