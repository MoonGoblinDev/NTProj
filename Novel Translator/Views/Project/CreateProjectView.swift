import SwiftUI

struct CreateProjectView: View {
    @EnvironmentObject var projectManager: ProjectManager
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
                    // The project manager will handle the file dialog and saving
                    projectManager.createProject(
                        name: projectName,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        description: projectDescription.isEmpty ? nil : projectDescription
                    )
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
}
