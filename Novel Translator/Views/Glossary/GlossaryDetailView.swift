import SwiftUI

typealias GlossaryCategory = GlossaryEntry.GlossaryCategory

struct GlossaryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectManager: ProjectManager
    
    @Binding var entry: GlossaryEntry
    @ObservedObject var project: TranslationProject
    
    let isCreating: Bool
    
    @State private var originalTerm: String
    @State private var translation: String
    @State private var category: GlossaryCategory
    @State private var contextDescription: String
    @State private var aliasesString: String
    @State private var gender: GlossaryEntry.Gender
    
    private var isFormValid: Bool {
        !originalTerm.trimmingCharacters(in: .whitespaces).isEmpty &&
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    init(entry: Binding<GlossaryEntry>, project: TranslationProject, isCreating: Bool) {
        self._entry = entry
        self._project = ObservedObject(wrappedValue: project)
        self.isCreating = isCreating
        
        _originalTerm = State(initialValue: entry.wrappedValue.originalTerm)
        _translation = State(initialValue: entry.wrappedValue.translation)
        _category = State(initialValue: entry.wrappedValue.category)
        _contextDescription = State(initialValue: entry.wrappedValue.contextDescription)
        _aliasesString = State(initialValue: entry.wrappedValue.aliases.joined(separator: ", "))
        _gender = State(initialValue: entry.wrappedValue.gender ?? .unknown)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Core Information") {
                    TextField("Original Term", text: $originalTerm)
                    TextField("Translation", text: $translation)
                    Picker("Category", selection: $category) {
                        ForEach(GlossaryCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    
                    if category == .character {
                        Picker("Gender", selection: $gender) {
                            ForEach(GlossaryEntry.Gender.allCases, id: \.self) { g in
                                Text(g.displayName).tag(g)
                            }
                        }
                    }
                }
                
                Section("Additional Context") {
                    TextField("Aliases (comma-separated)", text: $aliasesString)
                    
                    VStack(alignment: .leading) {
                        Text("Description / Notes")
                        TextEditor(text: $contextDescription)
                            .frame(minHeight: 80)
                            .cornerRadius(8)
                            .font(.body)
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()
            
            HStack {
                if !isCreating {
                    Button("Delete", role: .destructive) { deleteEntry() }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { saveEntry(); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 550, minHeight: 450)
        .navigationTitle(isCreating ? "New Glossary Entry" : "Edit Glossary Entry")
    }
    
    private func getFinalAliases() -> [String] {
        return aliasesString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    private func saveEntry() {
        let finalAliases = getFinalAliases()
        
        var updatedEntry = entry
        updatedEntry.originalTerm = originalTerm
        updatedEntry.translation = translation
        updatedEntry.category = category
        updatedEntry.contextDescription = contextDescription
        updatedEntry.aliases = finalAliases
        updatedEntry.gender = (category == .character) ? gender : nil
        
        if isCreating {
            project.glossaryEntries.append(updatedEntry)
        } else {
            self.entry = updatedEntry
        }
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
    
    private func deleteEntry() {
        project.glossaryEntries.removeAll { $0.id == entry.id }
        project.lastModifiedDate = Date()
        projectManager.saveProject()
        dismiss()
    }
}
