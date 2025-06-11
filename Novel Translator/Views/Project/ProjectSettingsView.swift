//
//  ProjectSettingsView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI
import SwiftData

struct ProjectSettingsView: View {
    @Bindable var project: TranslationProject
    @State private var isAPISettingsPresented = false

    var body: some View {
        Form {
            Section("Project Information") {
                TextField("Name", text: $project.name)
                    .onChange(of: project.name) { _, _ in project.lastModifiedDate = Date() }
                
                TextField("Source Language", text: $project.sourceLanguage)
                TextField("Target Language", text: $project.targetLanguage)
                
                VStack(alignment: .leading) {
                    Text("Description")
                    TextEditor(text: .init(
                        get: { project.projectDescription ?? "" },
                        set: { project.projectDescription = $0 }
                    ))
                    .frame(minHeight: 80)
                }
            }
            
            Section("API Configuration") {
                // MODIFIED: Use a button to present a sheet
                Button("Manage API Keys & Models") {
                    isAPISettingsPresented = true
                }
            }
            
            Section("Import Settings") {
                // This can remain a NavigationLink for now
                NavigationLink("Configure Import Rules", destination: ImportSettingsView(project: project))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
        .navigationTitle("Project Settings")
        .sheet(isPresented: $isAPISettingsPresented) {
            APISettingsView(project: project)
        }
    }
}

// Keep the placeholder view for ImportSettingsView
struct ImportSettingsView: View {
    @Bindable var project: TranslationProject
    var body: some View { Text("Import Settings for \(project.name)") }
}
