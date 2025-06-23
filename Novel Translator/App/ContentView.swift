import SwiftUI

struct ContentView: View {
    // Access the shared state object from the environment.
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        Group {
            if let project = projectManager.currentProject {
                // We use a 2-column split view. The "detail" area will contain our custom logic.
                NavigationSplitView {
                    SidebarView(project: project)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)

                } detail: {
                    // The magic happens here. We switch the detail's content based on visibility.
                    if appContext.isChatSidebarVisible {
                        // When visible, use an HSplitView for the resizable divider.
                        HSplitView {
                            TranslationWorkspaceView(project: project)
                                .frame(minWidth: 600)
                            
                            ChatView(project: project, projectManager: projectManager)
                        }
                    } else {
                        // When hidden, show only the workspace. It will now expand to fill the space.
                        TranslationWorkspaceView(project: project)
                    }
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
        // No .onChange modifier is needed here anymore. The logic is self-contained.
    }
}
