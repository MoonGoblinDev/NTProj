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

            // New section for editor settings
            Section("Editor Settings") {
                Toggle(isOn: $projectManager.settings.disableGlossaryHighlighting) {
                    Text("Disable Glossary Highlighting")
                    Text("Turn this on to improve performance on large chapters or to debug editor jitter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: projectManager.settings.disableGlossaryHighlighting) { _, _ in
                    // Save the settings whenever the toggle is changed.
                    projectManager.saveSettings()
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
