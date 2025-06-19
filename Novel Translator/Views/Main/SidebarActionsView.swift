import SwiftUI

struct SidebarActionsView: View {
    @Binding var selectedTab: SidebarTab
    @ObservedObject var project: TranslationProject // To pass to sheets
    @EnvironmentObject private var projectManager: ProjectManager
    
    // State for presenting sheets
    @State private var isImporterPresented = false
    @State private var isAddGlossaryPresented = false
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
                Button {
                    // Reset the new entry object before presenting the sheet
                    newGlossaryEntry = GlossaryEntry(originalTerm: "", translation: "", category: .character, contextDescription: "")
                    isAddGlossaryPresented = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
            case .settings, .stats, .search: // UPDATED
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
            // Pass the project object and a binding to the new entry struct
            GlossaryDetailView(entry: $newGlossaryEntry, project: project, isCreating: true)
                .environmentObject(projectManager)
        }
    }
}

#Preview {
    // This helper view allows testing the binding
    struct PreviewWrapper: View {
        @State private var selectedTab: SidebarTab = .chapters
        private let mocks = PreviewMocks.shared

        var body: some View {
            VStack {
                // The view being tested
                SidebarActionsView(
                    selectedTab: $selectedTab,
                    project: mocks.project
                )
                .environmentObject(mocks.projectManager)

                Divider()
                Text("Change Tab to See Button Change")
                Picker("Tab", selection: $selectedTab) {
                    ForEach(SidebarTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }
        }
    }
    return PreviewWrapper()
        .frame(width: 500)
}
