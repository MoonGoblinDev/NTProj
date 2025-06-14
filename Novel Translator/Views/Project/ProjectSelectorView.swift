import SwiftUI

struct ProjectSelectorView: View {
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        Menu {
            if let project = projectManager.project {
                // The current project is not a selectable item, just a title
                Section(project.name) {
                    Button("Save Project", action: projectManager.saveProject)
                        .disabled(!projectManager.isProjectDirty)
                    Button("Close Project", action: projectManager.closeProject)
                }
                Divider()
            }
            
            Button("Create New Project...", systemImage: "plus") {
                // This would typically present the creation sheet.
                // For simplicity, we assume another part of the UI handles this.
                // Or we can post a notification.
                // The WelcomeView handles this, so this button is for convenience.
            }
            
            Button("Open Project...", systemImage: "folder") {
                projectManager.openProject()
            }
            
            // TODO: Add a list of recent projects from UserDefaults
            
        } label: {
            HStack {
                Text(projectManager.project?.name ?? "No Project Open")
                    .fontWeight(.bold)
                    .lineLimit(1)
                Spacer()
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }
}
