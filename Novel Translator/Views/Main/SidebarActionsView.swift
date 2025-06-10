//
//  SidebarActionsView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI

struct SidebarActionsView: View {
    @Binding var selectedTab: SidebarTab
    let project: TranslationProject // To pass to sheets
    
    // State for presenting sheets
    @State private var isImporterPresented = false
    @State private var isAddGlossaryPresented = false
    
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
                    isAddGlossaryPresented = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
            case .settings:
                // No action button for settings tab
                EmptyView()
            case .stats:
                // No action button for stats tab
                EmptyView()
            }
        }
        .padding(12)
        // A subtle background to distinguish it from the content above
        .background(.background.secondary)
        .sheet(isPresented: $isImporterPresented) {
            ImportChapterView(project: project)
        }
        .sheet(isPresented: $isAddGlossaryPresented) {
            // Placeholder for the Create Glossary Entry view
            Text("Create Glossary Entry View")
        }
    }
}
