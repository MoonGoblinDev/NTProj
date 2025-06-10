//
//  ProjectSelectorView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI
import SwiftData

struct ProjectSelectorView: View {
    var projects: [TranslationProject]
    @Binding var selectedProjectID: PersistentIdentifier? // FIX
    var onAddProject: () -> Void
    
    private var selectedProjectName: String {
        guard let selectedProjectID, let project = projects.first(where: { $0.id == selectedProjectID }) else {
            return "Select a Project"
        }
        return project.name
    }
    
    var body: some View {
        Menu {
            // FIX: Explicitly type the Picker's selection
            Picker("Projects", selection: $selectedProjectID) {
                Text("Select a Project").tag(nil as PersistentIdentifier?)
                ForEach(projects) { project in
                    Text(project.name).tag(project.id as PersistentIdentifier?)
                }
            }
            .pickerStyle(.inline)
            
            Divider()
            
            Button("Create New Project...", systemImage: "plus", action: onAddProject)
            
        } label: {
            HStack {
                Text(selectedProjectName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }
}
