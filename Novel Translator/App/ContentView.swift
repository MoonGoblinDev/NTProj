import SwiftUI

struct ContentView: View {
    // Access the shared state object from the environment.
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        Group {
            if let project = projectManager.currentProject {
                NavigationSplitView {
                    // FIX: Pass the single active project to the SidebarView.
                    SidebarView(project: project)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

                } detail: {
                    // FIX: Pass the single active project to the TranslationWorkspaceView.
                    TranslationWorkspaceView(project: project)
                }
            } else {
                WelcomeView()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "noveltranslator", url.host == "glossary" else {
                return
            }
            
            // Just update the shared state. No notifications needed.
            if let uuid = UUID(uuidString: url.lastPathComponent) {
                appContext.glossaryEntryToEditID = uuid
            }
        }
    }
}
