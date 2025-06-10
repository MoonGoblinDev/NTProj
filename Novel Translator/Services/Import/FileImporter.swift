//
//  FileImporter.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import AppKit
import Foundation

enum FileImporterError: LocalizedError {
    case userCancelled
    case noFilesSelected
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "File selection was cancelled."
        case .noFilesSelected:
            return "No text files were selected or the folder was empty."
        }
    }
}

class FileImporter {
    @MainActor
    func openTextFiles() throws -> [URL] {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true // Allow selecting a folder
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [.plainText] // Only allow .txt files
        
        let response = openPanel.runModal()
        
        guard response == .OK else {
            throw FileImporterError.userCancelled
        }
        
        var fileURLs: [URL] = []
        for url in openPanel.urls {
            // If the URL is a directory, find all .txt files inside it
            if url.hasDirectoryPath {
                let fileManager = FileManager.default
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension.lowercased() == "txt" {
                            fileURLs.append(fileURL)
                        }
                    }
                }
            } else {
                // If it's a single file
                if url.pathExtension.lowercased() == "txt" {
                    fileURLs.append(url)
                }
            }
        }
        
        guard !fileURLs.isEmpty else {
            throw FileImporterError.noFilesSelected
        }
        
        return fileURLs.sorted { $0.lastPathComponent < $1.lastPathComponent } // Sort alphabetically
    }
}
