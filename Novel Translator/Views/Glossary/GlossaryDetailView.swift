//
//  GlossaryDetailView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI
import SwiftData

// Create a typealias for brevity
typealias GlossaryCategory = GlossaryEntry.GlossaryCategory

struct GlossaryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // The entry to edit, or nil if creating a new one.
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
    
    private var navTitle: String {
        entry == nil ? "New Glossary Entry" : "Edit Glossary Entry"
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
        .navigationTitle(navTitle)
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
            // Editing existing entry
            entry.originalTerm = originalTerm
            entry.translation = translation
            entry.category = category
            entry.contextDescription = contextDescription.isEmpty ? nil : contextDescription
            entry.aliases = finalAliases
        } else {
            // Creating new entry
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
