//
//  ProjectViewModel.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI
import SwiftData

@Observable
class ProjectViewModel {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // createProject function remains the same...
    func createProject(name: String, sourceLang: String, targetLang: String, description: String?) {
            // 1. Create the main project object
            let newProject = TranslationProject(
                name: name,
                sourceLanguage: sourceLang,
                targetLanguage: targetLang,
                description: description
            )
            
            // 2. Create API configurations for all providers
            for provider in APIConfiguration.APIProvider.allCases {
                let apiConfig = APIConfiguration(provider: provider)
                // Create a unique keychain identifier per project, per provider
                apiConfig.apiKeyIdentifier = "com.noveltranslator.\(newProject.id.uuidString).\(provider.rawValue)"
                apiConfig.project = newProject
                newProject.apiConfigurations.append(apiConfig)
                modelContext.insert(apiConfig)
            }
            
            // 3. Set a sensible default selected model and enable it
            let defaultProvider = APIConfiguration.APIProvider.google
            if let defaultModel = defaultProvider.defaultModels.first {
                newProject.selectedProvider = defaultProvider
                newProject.selectedModel = defaultModel
                
                // Also enable this model by default in its configuration
                if let googleConfig = newProject.apiConfigurations.first(where: { $0.provider == defaultProvider }) {
                    googleConfig.enabledModels.append(defaultModel)
                }
            }
            
            // 4. Create initial statistics object
            let stats = TranslationStats(projectId: newProject.id)
            
    // ... rest of the function is the same ...
            // 5. Create default import settings
            let importSettings = ImportSettings(projectId: newProject.id)
            
            // 6. Insert all new objects into the context
            modelContext.insert(newProject)
            modelContext.insert(stats)
            modelContext.insert(importSettings)
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save new project: \(error.localizedDescription)")
            }
        }
    
    func deleteProject(_ project: TranslationProject) {
        let projectId = project.id

        // The .cascade delete rule handles Chapters, GlossaryEntries, and APIConfiguration.
        // We must manually delete models linked only by the projectId.
        
        // Delete associated TranslationStats
        do {
            let statsDescriptor = FetchDescriptor<TranslationStats>(predicate: #Predicate { $0.projectId == projectId })
            if let statsToDelete = try? modelContext.fetch(statsDescriptor) {
                statsToDelete.forEach { modelContext.delete($0) }
            }
        }

        // Delete associated ImportSettings
        do {
            let settingsDescriptor = FetchDescriptor<ImportSettings>(predicate: #Predicate { $0.projectId == projectId })
            if let settingsToDelete = try? modelContext.fetch(settingsDescriptor) {
                settingsToDelete.forEach { modelContext.delete($0) }
            }
        }

        // Finally, delete the project itself
        modelContext.delete(project)
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully deleted project and its associated data.")
        } catch {
            print("Failed to save after deleting project: \(error.localizedDescription)")
        }
    }
}
