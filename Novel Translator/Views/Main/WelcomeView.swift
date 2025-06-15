import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var isCreatingProject = false
    
    private var recentProjects: [ProjectMetadata] {
        Array(projectManager.settings.projects.prefix(5))
    }
    
    var body: some View {
        VStack {
            ContentUnavailableView {
                Label("Welcome to Novel Translator", systemImage: "book.and.globe")
                    .font(.largeTitle)
            } description: {
                Text("Create a new project or open an existing one to begin.")
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
                
                HStack(spacing: 12) {
                    Button("Create New Project...") {
                        isCreatingProject = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Open Project...") {
                        projectManager.openProject()
                    }
                }
            }
            
            if !recentProjects.isEmpty {
                Divider().padding()
                Text("Recent Projects").font(.title2)
                List(recentProjects) { projectMeta in
                    Button {
                        projectManager.switchProject(to: projectMeta)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(projectMeta.name).fontWeight(.bold)
                            // FIX: Removed the file path display as it's no longer directly available
                            // and requires resolving the bookmark, which is best avoided in the view.
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
                .frame(maxWidth: 400, maxHeight: 200)
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            CreateProjectView()
        }
    }
}
