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
            case .settings, .stats:
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
            // Present the detail view for CREATING a new entry (entry is nil)
            GlossaryDetailView(entry: nil, project: project)
        }
    }
}
