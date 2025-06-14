//
//  GlossaryDetailView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI
import SwiftData

typealias GlossaryCategory = GlossaryEntry.GlossaryCategory

struct GlossaryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var entry: GlossaryEntry?
    var project: TranslationProject
    
    @State private var originalTerm: String = ""
    @State private var translation: String = ""
    @State private var category: GlossaryCategory = .character
    @State private var contextDescription: String = ""
    @State private var aliasesString: String = ""
    
    private var isFormValid: Bool {
        !originalTerm.trimmingCharacters(in: .whitespaces).isEmpty &&
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
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
                if entry != nil {
                    Button("Delete", role: .destructive) {
                        deleteEntry()
                    }
                }
                
                Spacer()
                
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                
                Button("Save") {
                    saveEntry()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 550, minHeight: 450)
        .navigationTitle("Glossary Entry")
        .onAppear(perform: loadEntryData)
    }
    
    private func loadEntryData() {
        guard let entry = entry else { return }
        originalTerm = entry.originalTerm
        translation = entry.translation
        category = entry.category
        contextDescription = entry.contextDescription ?? ""
        aliasesString = entry.aliases.joined(separator: ", ")
    }
    
    private func getFinalAliases() -> [String] {
        return aliasesString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    private func saveEntry() {
        let finalAliases = getFinalAliases()
        
        if let entry = entry {
            entry.originalTerm = originalTerm
            entry.translation = translation
            entry.category = category
            entry.contextDescription = contextDescription.isEmpty ? nil : contextDescription
            entry.aliases = finalAliases
        } else {
            let newEntry = GlossaryEntry(
                originalTerm: originalTerm,
                translation: translation,
                category: category,
                contextDescription: contextDescription.isEmpty ? nil : contextDescription,
                aliases: finalAliases
            )
            newEntry.project = project
            modelContext.insert(newEntry)
        }
        project.lastModifiedDate = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save glossary entry: \(error)")
        }
    }
    
    private func deleteEntry() {
        guard let entry = entry else { return }
        modelContext.delete(entry)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to delete glossary entry: \(error)")
        }
    }
}

#Preview("New Entry") {
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        var body: some View {
            NavigationStack {
                GlossaryDetailView(entry: nil, project: projects.first!)
            }
        }
    }
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    container.mainContext.insert(TranslationProject(name: "Sample", sourceLanguage: "A", targetLanguage: "B"))
    
    return Previewer()
        .modelContainer(container)
}

#Preview("Edit Entry") {
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        var body: some View {
            NavigationStack {
                GlossaryDetailView(entry: projects.first!.glossaryEntries.first!, project: projects.first!)
            }
        }
    }
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    let project = TranslationProject(name: "Sample", sourceLanguage: "A", targetLanguage: "B")
    let entry = GlossaryEntry(originalTerm: "主人公", translation: "Protagonist", category: .character, aliases: ["main character"])
    project.glossaryEntries.append(entry)
    container.mainContext.insert(project)
    
    return Previewer()
        .modelContainer(container)
}
