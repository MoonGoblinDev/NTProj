import SwiftUI

struct SidebarView: View {
    @ObservedObject var project: TranslationProject
    
    @State private var selectedTab: SidebarTab = .chapters
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Picker("Sidebar Tab", selection: $selectedTab) {
                    ForEach(SidebarTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // The content for the selected tab
                switch selectedTab {
                case .chapters:
                    ChapterListView(project: project)
                case .glossary:
                    GlossaryView(project: project)
                case .search:
                    SearchView(project: project)
                case .settings:
                    ProjectSettingsView(project: project)
                case .stats:
                    ProjectStatsView(project: project)
                }
            }
            
            // The unified action bar at the bottom.
            SidebarActionsView(selectedTab: $selectedTab, project: project)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OpaqueVisualEffect().ignoresSafeArea())
    }
}
