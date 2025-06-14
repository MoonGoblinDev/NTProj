//
//  PromptPreset.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 14/06/25.
//

import SwiftData
import Foundation

@Model
final class PromptPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var prompt: String
    var createdDate: Date
    var lastModifiedDate: Date

    // Relationship
    var project: TranslationProject?

    init(name: String, prompt: String, project: TranslationProject? = nil) {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.createdDate = Date()
        self.lastModifiedDate = Date()
        self.project = project
    }
    
    static var defaultPrompt: String {
        """
        You are an expert novel translator. Your task is to translate the following text from {{SOURCE_LANGUAGE}} to {{TARGET_LANGUAGE}}.
        Preserve the original tone, style, and formatting, including line breaks.
        
        {{GLOSSARY}}
        Now, translate the following text:
        --- TEXT TO TRANSLATE START ---
        {{TEXT}}
        --- TEXT TO TRANSLATE END ---
        """
    }
}
