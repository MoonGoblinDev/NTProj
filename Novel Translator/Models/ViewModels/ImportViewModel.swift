//
//  ImportViewModel.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI
import SwiftData

@Observable
@MainActor
class ImportViewModel {
    var project: TranslationProject
    private var modelContext: ModelContext
    
    var isImporting = false
    var importProgress: Double = 0.0
    var importMessage = ""
    var importedChapters: [Chapter] = []
    
    private let fileImporter = FileImporter()
    private let chapterDetector = ChapterDetector()

    init(project: TranslationProject, modelContext: ModelContext) {
        self.project = project
        self.modelContext = modelContext
    }
    
    func startImport() async {
        isImporting = true
        importProgress = 0.0
        importMessage = "Selecting files..."
        importedChapters.removeAll()
        
        do {
            // Step 1: Use FileImporter to get file URLs
            let urls = try fileImporter.openTextFiles()
            guard !urls.isEmpty else {
                importMessage = "No files selected or folder was empty."
                isImporting = false
                return
            }
            
            importMessage = "Parsing \(urls.count) file(s)..."
            
            // Step 2: Process each file
            for (index, url) in urls.enumerated() {
                importMessage = "Processing: \(url.lastPathComponent)"
                let content = try String(contentsOf: url, encoding: .utf8)
                
                // Retrieve the project's specific import settings
                let settings = fetchImportSettings()
                
                // Step 3: Use ChapterDetector to get Chapter objects
                let detectedChapters = chapterDetector.detect(from: content, using: settings, filename: url.deletingPathExtension().lastPathComponent)
                
                // Append chapters but don't save yet to do it in one batch
                self.importedChapters.append(contentsOf: detectedChapters)
                
                // Update progress
                importProgress = Double(index + 1) / Double(urls.count)
            }
            
            // Step 4: Save to SwiftData
            await saveChapters()
            
        } catch let error as FileImporterError {
            importMessage = error.localizedDescription
        } catch {
            importMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        isImporting = false
    }
    
    private func fetchImportSettings() -> ImportSettings {
        let projectId = project.id
        let descriptor = FetchDescriptor<ImportSettings>(predicate: #Predicate { $0.projectId == projectId })
        if let settings = try? modelContext.fetch(descriptor).first {
            return settings
        }
        // Return default settings if none are found for the project
        return ImportSettings(projectId: projectId)
    }
    
    private func saveChapters() async {
        guard !importedChapters.isEmpty else {
            importMessage = "No new chapters were detected."
            return
        }
        
        importMessage = "Saving \(importedChapters.count) chapters..."
        
        // Find the highest existing chapter number to continue the sequence
        let maxChapterNumber = project.chapters.map(\.chapterNumber).max() ?? 0
        
        for (index, var chapter) in importedChapters.enumerated() {
            chapter.chapterNumber = maxChapterNumber + index + 1
            chapter.project = self.project // Establish the relationship
            modelContext.insert(chapter)
        }
        
        do {
            try modelContext.save()
            importMessage = "Successfully imported \(importedChapters.count) new chapters!"
            project.lastModifiedDate = Date()
        } catch {
            importMessage = "Error saving chapters: \(error.localizedDescription)"
        }
    }
}
