import SwiftUI
import SwiftData

struct SidebarView: View {
    var projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier?
    @Binding var selectedChapterID: PersistentIdentifier?
    
    @State private var isCreatingProject = false
    @State private var selectedTab: SidebarTab = .chapters
    
    private var selectedProject: TranslationProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }
    
    var body: some View {
        // Main container for the entire sidebar
        VStack(spacing: 0) {
            // --- TOP: PROJECT SELECTOR ---
            ProjectSelectorView(
                projects: projects,
                selectedProjectID: $selectedProjectID,
                onAddProject: { isCreatingProject = true }
            )
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            // Show content only if a project is selected
            if let project = selectedProject {
                // --- MIDDLE: CUSTOM TAB PICKER & CONTENT ---
                VStack(spacing: 0) {
                    Picker("Sidebar Tab", selection: $selectedTab) {
                        ForEach(SidebarTab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // The switch statement displays the correct view
                    // The views themselves will be modified to fill the space
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
                
                // --- BOTTOM: UNIFIED ACTION BAR ---
                SidebarActionsView(selectedTab: $selectedTab, project: project)

            } else {
                // Placeholder when no project is selected, fills the whole space
                Spacer()
                ContentUnavailableView("No Project Selected", systemImage: "book.closed")
                Spacer()
            }
        }
        // --- FIX: CONSISTENT BACKGROUND ---
        // Fills the entire sidebar with the standard window background color
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isCreatingProject) {
            CreateProjectView()
        }
        .onChange(of: selectedProjectID) {
            selectedTab = .chapters
        }
    }
}
