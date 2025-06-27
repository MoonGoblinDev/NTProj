import SwiftUI

@Observable
@MainActor
class ImportViewModel {
    var project: TranslationProject
    
    var isImporting = false
    var importProgress: Double = 0.0
    var importMessage = ""
    
    private let fileImporter = FileImporter()
    private let chapterDetector = ChapterDetector()

    init(project: TranslationProject) {
        self.project = project
    }
    
    func startImport() async -> Bool {
        isImporting = true
        importProgress = 0.0
        importMessage = "Selecting files..."
        
        do {
            // Step 1: Use FileImporter to get file URLs
            let urls = try fileImporter.openTextFiles()
            guard !urls.isEmpty else {
                importMessage = "No files selected or folder was empty."
                isImporting = false
                return false
            }
            
            importMessage = "Parsing \(urls.count) file(s)..."
            var allDetectedChapters: [Chapter] = []
            
            // Step 2: Process each file
            for (index, url) in urls.enumerated() {
                importMessage = "Processing: \(url.lastPathComponent)"
                let content = try String(contentsOf: url, encoding: .utf8)
                
                let settings = project.importSettings
                
                // Step 3: Use ChapterDetector to get Chapter objects, passing the filename
                let filenameWithoutExtension = url.deletingPathExtension().lastPathComponent
                let detectedChapters = chapterDetector.detect(from: content, using: settings, filename: filenameWithoutExtension)
                
                allDetectedChapters.append(contentsOf: detectedChapters)
                
                importProgress = Double(index + 1) / Double(urls.count)
            }
            
            // Step 4: Check if we actually found anything to import
            guard !allDetectedChapters.isEmpty else {
                importMessage = "No new chapters were detected in the selected file(s)."
                isImporting = false
                return false
            }
            
            // Step 5: Add to project model in memory
            appendChapters(allDetectedChapters)
            
            importMessage = "Successfully imported \(allDetectedChapters.count) new chapters! Saving project..."
            project.lastModifiedDate = Date()
            
            isImporting = false
            return true
            
        } catch let error as FileImporterError {
            importMessage = error.localizedDescription
            isImporting = false
            return false
        } catch {
            importMessage = "An unexpected error occurred: \(error.localizedDescription)"
            isImporting = false
            return false
        }
    }
    
    private func appendChapters(_ newChapters: [Chapter]) {
        // The check for an empty array is now handled in startImport().
        
        // Find the highest existing chapter number to continue the sequence
        let maxChapterNumber = project.chapters.map(\.chapterNumber).max() ?? 0
        
        for (index, var chapter) in newChapters.enumerated() {
            chapter.chapterNumber = maxChapterNumber + index + 1
            project.chapters.append(chapter)
        }
    }
}
