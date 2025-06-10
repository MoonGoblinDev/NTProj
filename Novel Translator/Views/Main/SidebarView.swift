import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedProjectID: PersistentIdentifier?
    @Binding var selectedChapterID: PersistentIdentifier?
    var projects: [TranslationProject] // Still needed to find the selected project
    
    @State private var selectedTab: SidebarTab = .chapters
    
    private var selectedProject: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // The ProjectSelectorView has been REMOVED from here.
            
            if let project = selectedProject {
                VStack(spacing: 0) {
                    Picker("Sidebar Tab", selection: $selectedTab) {
                        ForEach(SidebarTab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // The content for the selected tab
                    switch selectedTab {
                    case .chapters:
                        ChapterListView(project: project, selectedChapterID: $selectedChapterID)
                    case .glossary:
                        GlossaryView(project: project)
                    case .settings:
                        ProjectSettingsView(project: project)
                    case .stats:
                        ProjectStatsView(project: project)
                    }
                }
                
                // The unified action bar at the bottom.
                SidebarActionsView(selectedTab: $selectedTab, project: project)
            } else {
                Spacer()
                ContentUnavailableView("No Project Selected", systemImage: "book.closed")
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: selectedProjectID) {
            selectedTab = .chapters
        }
    }
}
