//
//  ProjectManager.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 14/06/25.
//

import SwiftUI

@MainActor
class ProjectManager: ObservableObject {
    @Published private(set) var project: TranslationProject?
    @Published private(set) var projectURL: URL?
    
    // This will be populated by WorkspaceViewModel
    var isProjectDirty: Bool = false

    private let jsonEncoder = JSONEncoder.prettyEncoder
    private let jsonDecoder = JSONDecoder()

    func openProject() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.json]

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                self.project = try jsonDecoder.decode(TranslationProject.self, from: data)
                self.projectURL = url
                self.isProjectDirty = false
            } catch {
                // TODO: Present an error alert to the user
                print("Failed to open or decode project: \(error)")
            }
        }
    }

    func createProject(name: String, sourceLanguage: String, targetLanguage: String, description: String?) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(name).json"

        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            let newProject = TranslationProject(name: name, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, description: description)
            
            // Add default configurations
            for provider in APIConfiguration.APIProvider.allCases {
                var apiConfig = APIConfiguration(provider: provider)
                apiConfig.apiKeyIdentifier = "com.noveltranslator.\(newProject.id.uuidString).\(provider.rawValue)"
                newProject.apiConfigurations.append(apiConfig)
            }
            let defaultProvider = APIConfiguration.APIProvider.google
            if let defaultModel = defaultProvider.defaultModels.first {
                newProject.selectedProvider = defaultProvider
                newProject.selectedModel = defaultModel
                if let googleConfig = newProject.apiConfigurations.first(where: { $0.provider == defaultProvider }) {
                    var mutableGoogleConfig = googleConfig
                    mutableGoogleConfig.enabledModels.append(defaultModel)
                    newProject.apiConfigurations[0] = mutableGoogleConfig // Assumes it's the first
                }
            }
            
            let defaultPreset = PromptPreset(name: "Default", prompt: PromptPreset.defaultPrompt)
            newProject.promptPresets.append(defaultPreset)
            newProject.selectedPromptPresetID = defaultPreset.id
            
            self.project = newProject
            self.projectURL = url
            self.isProjectDirty = false
            saveProject()
        }
    }

    func saveProject() {
        guard let project = project, let url = projectURL else {
            print("No project or URL to save.")
            return
        }
        
        do {
            let data = try jsonEncoder.encode(project)
            try data.write(to: url, options: .atomic)
            self.isProjectDirty = false
            print("Project saved to \(url.path)")
        } catch {
            // TODO: Present an error alert to the user
            print("Failed to save project: \(error)")
        }
    }
    
    func closeProject() {
        // TODO: Check for unsaved changes before closing
        self.project = nil
        self.projectURL = nil
        self.isProjectDirty = false
    }
}
