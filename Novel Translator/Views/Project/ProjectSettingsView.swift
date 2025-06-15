import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject var project: TranslationProject
    @State private var isAPISettingsPresented = false

    var body: some View {
        Form {
            Section("Project Information") {
                TextField("Name", text: $project.name)
                
                TextField("Source Language", text: $project.sourceLanguage)
                TextField("Target Language", text: $project.targetLanguage)
                
                VStack(alignment: .leading) {
                    Text("Description")
                    TextEditor(text: .init(
                        get: { project.projectDescription ?? "" },
                        set: { project.projectDescription = $0 }
                    ))
                    .frame(minHeight: 80)
                }
            }
            
            Section("API Configuration (Global)") {
                Button("Manage API Keys & Models") {
                    isAPISettingsPresented = true
                }
            }
            
            Section("Import Settings") {
                // In a future update, this could be a sheet too.
                // For now, it edits the project object directly.
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Auto-Detect Chapters", isOn: $project.importSettings.autoDetectChapters)
                    TextField("Chapter Separator", text: $project.importSettings.chapterSeparator)
                        .disabled(!project.importSettings.autoDetectChapters)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
        .navigationTitle("")
        .sheet(isPresented: $isAPISettingsPresented) {
            APISettingsView(projectManager: projectManager)
        }
    }
}
