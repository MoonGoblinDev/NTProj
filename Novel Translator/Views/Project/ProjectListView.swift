//
//  ProjectListView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranslationProject.lastModifiedDate, order: .reverse) private var projects: [TranslationProject]
    @Binding var selection: TranslationProject.ID?
    @State private var isCreatingProject = false

    var body: some View {
        List(projects, selection: $selection) { project in
            Text(project.name)
                .tag(project.id)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem {
                Button(action: { isCreatingProject = true }) {
                    Label("Add Project", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            // Pass the model context to the sheet's environment
            CreateProjectView()
                .environment(\.modelContext, modelContext)
        }
    }
}
