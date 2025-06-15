//
//  TranslationWorkspaceToolbar.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 16/06/25.
//

import SwiftUI

struct TranslationWorkspaceToolbar: ToolbarContent {
    @ObservedObject var projectManager: ProjectManager
    
    @Binding var isPresetsViewPresented: Bool
    
    private var selectedPresetName: String {
        if let presetID = projectManager.settings.selectedPromptPresetID,
           let preset = projectManager.settings.promptPresets.first(where: { $0.id == presetID }) {
            return preset.name
        }
        return "Default Prompt"
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            ProjectSelectorView()
        }
        
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isPresetsViewPresented = true
            } label: {
                Label("Manage Prompts", systemImage: "text.quote")
            }
            
            Menu {
                Picker("Prompt Preset", selection: $projectManager.settings.selectedPromptPresetID) {
                    Text("Default Prompt").tag(nil as UUID?)
                    Divider()
                    ForEach(projectManager.settings.promptPresets.sorted(by: { $0.createdDate < $1.createdDate })) { preset in
                        Text(preset.name).tag(preset.id as UUID?)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: projectManager.settings.selectedPromptPresetID) { _, _ in projectManager.saveSettings() }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedPresetName)
                        .lineLimit(1)
                }
            }
            .menuIndicator(.visible)
            .fixedSize()
            
            Divider()
            
            Menu {
                ForEach(projectManager.settings.apiConfigurations.filter { !$0.enabledModels.isEmpty }) { config in
                    Section(config.provider.displayName) {
                        ForEach(config.enabledModels, id: \.self) { modelName in
                            Button {
                                projectManager.settings.selectedProvider = config.provider
                                projectManager.settings.selectedModel = modelName
                                projectManager.saveSettings()
                            } label: {
                                HStack {
                                    Text(modelName)
                                    if projectManager.settings.selectedProvider == config.provider && projectManager.settings.selectedModel == modelName {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    Text(projectManager.settings.selectedModel.isEmpty ? "Select Model" : projectManager.settings.selectedModel)
                        .lineLimit(1)
                }
            }
            .menuIndicator(.visible)
            .fixedSize()
            .disabled(projectManager.settings.apiConfigurations.allSatisfy { $0.enabledModels.isEmpty })
        }
    }
}
