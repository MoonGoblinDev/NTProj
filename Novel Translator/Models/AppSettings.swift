// FILE: Novel Translator/Models/AppSettings.swift
//
//  AppSettings.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 14/06/25.
//

import Foundation

/// A model to hold a project's metadata for the recent projects list.
struct ProjectMetadata: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var bookmarkData: Data
    var lastOpened: Date
}

/// The main container for global application settings, persisted as a single JSON file.
struct AppSettings: Codable {
    var apiConfigurations: [APIConfiguration] = []
    var promptPresets: [PromptPreset] = []
    var projects: [ProjectMetadata] = []
    
    // Global selections, formerly in TranslationProject
    var selectedProvider: APIConfiguration.APIProvider?
    var selectedModel: String = ""
    var selectedPromptPresetID: UUID?

    // New setting for disabling glossary highlighting
    var disableGlossaryHighlighting: Bool = false

    /// Default initializer for the first launch.
    init() {
        // Initialize with default API provider configs
        for provider in APIConfiguration.APIProvider.allCases {
            var apiConfig = APIConfiguration(provider: provider)
            // Use a stable identifier format not tied to a project UUID
            apiConfig.apiKeyIdentifier = "com.noveltranslator.apikey.\(provider.rawValue)"
            // Set default baseURL for Ollama
            if provider == .ollama {
                apiConfig.baseURL = "http://localhost:11434"
            }
            self.apiConfigurations.append(apiConfig)
        }

        // Set a default provider and model
        let defaultProvider = APIConfiguration.APIProvider.google
        if let defaultModel = defaultProvider.defaultModels.first {
            self.selectedProvider = defaultProvider
            self.selectedModel = defaultModel
        }

        // Add the default prompt preset
        let defaultPreset = PromptPreset(name: "Default", prompt: PromptPreset.defaultPrompt)
        self.promptPresets.append(defaultPreset)
        self.selectedPromptPresetID = defaultPreset.id
    }
}
