import SwiftUI

struct SidebarActionsView: View {
    @Binding var selectedTab: SidebarTab
    @ObservedObject var project: TranslationProject // To pass to sheets
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var workspaceViewModel: WorkspaceViewModel
    
    // State for presenting sheets
    @State private var isImporterPresented = false
    @State private var isAddGlossaryPresented = false
    @State private var isGlossaryAssistantPresented = false // New state
    @State private var newGlossaryEntry = GlossaryEntry(originalTerm: "", translation: "", category: .character, contextDescription: "")
    
    var body: some View {
        HStack {
            Spacer()
            // The button changes based on the selected tab
            switch selectedTab {
            case .chapters:
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Import Chapters", systemImage: "square.and.arrow.down")
                }
            case .glossary:
                Menu {
                    Button("Add Manually...") {
                        newGlossaryEntry = GlossaryEntry(originalTerm: "", translation: "", category: .character, contextDescription: "")
                        isAddGlossaryPresented = true
                    }
                    
                    Button("Glossary Assistant...") {
                        isGlossaryAssistantPresented = true
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

            case .settings, .stats, .search:
                // No action button for these tabs
                EmptyView()
            }
        }
        .padding(12)
        .background(.background.secondary)
        .sheet(isPresented: $isImporterPresented) {
            ImportChapterView(project: project)
        }
        .sheet(isPresented: $isAddGlossaryPresented) {
            GlossaryDetailView(entry: $newGlossaryEntry, project: project, isCreating: true)
                .environmentObject(projectManager)
        }
        .sheet(isPresented: $isGlossaryAssistantPresented) {
            GlossaryAssistantView(project: project, projectManager: projectManager, currentChapterID: workspaceViewModel.activeChapterID)
        }
    }
}
