import SwiftUI

struct ContentView: View {
    // Access the shared state object from the environment.
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        Group {
            if let project = projectManager.currentProject {
                // Use a 2-column split view with inspector for right sidebar
                NavigationSplitView {
                    SidebarView(project: project)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 600)
                } detail: {
                    TranslationWorkspaceView(project: project)
                        .frame(minWidth: 600)
                }
                .inspector(isPresented: $appContext.isInspectorVisible) {
                    // Use the new InspectorView which contains the tabs
                    InspectorView(
                        project: project,
                        projectManager: projectManager,
                        workspaceViewModel: workspaceViewModel
                    )
                    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
                    .toolbar {
                        Button {
                            withAnimation(.spring()) {
                                appContext.isInspectorVisible.toggle()
                            }
                        } label: {
                            Label("Toggle Inspector", systemImage: "sidebar.right")
                        }
                        .symbolVariant(appContext.isInspectorVisible ? .fill : .none)
                        .keyboardShortcut("b", modifiers: [.command, .shift])
                        .help("Toggle Inspector Panel (⌘⇧B)")
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
        
    }
        
}
