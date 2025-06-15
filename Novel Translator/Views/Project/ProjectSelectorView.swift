import SwiftUI

struct ProjectSelectorView: View {
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        Menu {
            if let project = projectManager.currentProject {
                Section(project.name) {
                    Button("Save Project") {
                        // This logic should be moved to the app's Command handler
                        // to ensure it's triggered from one place.
                        // For now, we'll call the manager directly.
                        NotificationCenter.default.post(name: .init("saveProjectCommand"), object: nil)
                    }
                    .disabled(!projectManager.isProjectDirty)
                    Button("Close Project", action: projectManager.closeProject)
                }
                Divider()
            }
            
            // FIX: Filter by project ID instead of path for correctness and simplicity.
            let otherProjects = projectManager.settings.projects.filter {
                $0.id != projectManager.currentProject?.id
            }
            
            if !otherProjects.isEmpty {
                Section("Switch Project") {
                    ForEach(otherProjects) { metadata in
                        Button(metadata.name) {
                            projectManager.switchProject(to: metadata)
                        }
                    }
                }
                Divider()
            }
            
            // Re-creating these from WelcomeView for convenience
            Button("Create New Project...", systemImage: "plus") {
                // This is a bit of a hack. A better way would be a shared state object.
                // For now, post a notification that WelcomeView or ContentView can catch.
                NotificationCenter.default.post(name: .init("showCreateProjectSheet"), object: nil)
            }
            
            Button("Open Project...", systemImage: "folder") {
                projectManager.openProject()
            }
            
        } label: {
            HStack {
                Text(projectManager.currentProject?.name ?? "No Project Open")
                    .fontWeight(.bold)
                    .lineLimit(1)
                Spacer()
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
        }
        //.menuStyle(.borderlessButton)
        .frame(width: 120)
    }
}
