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
                    SidebarView(project: project)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

                } detail: {
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
            
            if let uuid = UUID(uuidString: url.lastPathComponent) {
                appContext.glossaryEntryIDForDetail = uuid
            }
        }
    }
}
