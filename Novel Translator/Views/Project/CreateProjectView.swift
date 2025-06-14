//
//  CreateProjectView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI

struct CreateProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName: String = ""
    @State private var sourceLanguage: String = "Japanese"
    @State private var targetLanguage: String = "English"
    @State private var projectDescription: String = ""
    
    private var isFormValid: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Project Name", text: $projectName)
                    TextField("Source Language", text: $sourceLanguage)
                    TextField("Target Language", text: $targetLanguage)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $projectDescription)
                        .frame(minHeight: 100)
                        .cornerRadius(8)
                        .font(.body)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Project") {
                    createProject()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 400)
        .navigationTitle("New Translation Project")
    }
    
    private func createProject() {
        let viewModel = ProjectViewModel(modelContext: modelContext)
        viewModel.createProject(
            name: projectName,
            sourceLang: sourceLanguage,
            targetLang: targetLanguage,
            description: projectDescription.isEmpty ? nil : projectDescription
        )
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: TranslationProject.self, inMemory: true)
}
