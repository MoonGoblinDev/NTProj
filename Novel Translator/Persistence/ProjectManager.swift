//
//  ProjectManager.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 14/06/25.
//

import SwiftUI
import Foundation

@MainActor
class ProjectManager: ObservableObject {
    @Published private(set) var currentProject: TranslationProject?
    @Published private(set) var currentProjectURL: URL?
    @Published var settings: AppSettings
    
    var isProjectDirty: Bool = false

    private let jsonEncoder = JSONEncoder.prettyEncoder
    private let jsonDecoder = JSONDecoder()
    private let settingsURL: URL

    init() {
        // Default to an empty settings object
        self.settings = AppSettings()

        // Determine the URL for our settings file
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let appFolderURL = appSupportURL.appendingPathComponent("Novel Translator", isDirectory: true)
            
            if !fileManager.fileExists(atPath: appFolderURL.path) {
                try fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            self.settingsURL = appFolderURL.appendingPathComponent("settings.json")
        } catch {
            // Fallback for sandboxed environments or if App Support is unavailable
            fatalError("Could not create or access Application Support directory: \(error)")
        }
        
        loadSettings()
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        do {
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                let data = try Data(contentsOf: settingsURL)
                self.settings = try jsonDecoder.decode(AppSettings.self, from: data)
                print("App settings loaded from \(settingsURL.path)")
            } else {
                // First launch, create default settings and save them.
                print("No settings file found. Creating default settings.")
                self.settings = AppSettings()
                saveSettings()
            }
        } catch {
            print("Failed to load or decode settings, using defaults. Error: \(error)")
            self.settings = AppSettings()
        }
    }
    
    func saveSettings() {
        do {
            let data = try jsonEncoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            // TODO: Present an error alert to the user
            print("Failed to save app settings: \(error)")
        }
    }

    // MARK: - Project Management

    func openProject() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.json]

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            loadProject(from: url)
        }
    }

    func createProject(name: String, sourceLanguage: String, targetLanguage: String, description: String?) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(name).json"

        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            let newProject = TranslationProject(name: name, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, description: description)
            
            self.currentProject = newProject
            self.currentProjectURL = url
            self.isProjectDirty = false
            saveProject() // Save the new project file to disk
            updateProjectMetadata(for: newProject, at: url)
        }
    }
    
    func switchProject(to metadata: ProjectMetadata) {
        let url = URL(fileURLWithPath: metadata.path)
        loadProject(from: url)
    }

    func saveProject() {
        guard let project = currentProject, let url = currentProjectURL else {
            print("No project or URL to save.")
            return
        }
        
        do {
            let data = try jsonEncoder.encode(project)
            try data.write(to: url, options: .atomic)
            self.isProjectDirty = false
            updateProjectMetadata(for: project, at: url) // Update name if it changed
            print("Project saved to \(url.path)")
        } catch {
            // TODO: Present an error alert to the user
            print("Failed to save project: \(error)")
        }
    }
    
    func closeProject() {
        // TODO: Check for unsaved changes before closing
        self.currentProject = nil
        self.currentProjectURL = nil
        self.isProjectDirty = false
    }
    
    private func loadProject(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let project = try jsonDecoder.decode(TranslationProject.self, from: data)
            self.currentProject = project
            self.currentProjectURL = url
            self.isProjectDirty = false
            updateProjectMetadata(for: project, at: url)
        } catch {
            // TODO: Present an error alert to the user
            print("Failed to open or decode project: \(error)")
        }
    }
    
    private func updateProjectMetadata(for project: TranslationProject, at url: URL) {
        if let index = settings.projects.firstIndex(where: { $0.id == project.id }) {
            // Update existing entry
            settings.projects[index].name = project.name
            settings.projects[index].lastOpened = Date()
        } else {
            // Add new entry
            let newMetadata = ProjectMetadata(id: project.id, name: project.name, path: url.path, lastOpened: Date())
            settings.projects.append(newMetadata)
        }
        
        // Sort projects by last opened date
        settings.projects.sort { $0.lastOpened > $1.lastOpened }
        
        saveSettings()
    }
}
