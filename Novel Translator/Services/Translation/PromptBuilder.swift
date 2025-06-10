//
//  PromptBuilder.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

class PromptBuilder {
    func buildTranslationPrompt(
        text: String,
        glossaryMatches: [GlossaryMatch],
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        var prompt = """
        You are an expert novel translator. Your task is to translate the following text from \(sourceLanguage) to \(targetLanguage).
        Preserve the original tone, style, and formatting, including line breaks.
        
        """

        if !glossaryMatches.isEmpty {
            prompt += "CRITICAL: You MUST use the following translations for specific terms. Do not deviate from them.\n"
            prompt += "--- GLOSSARY START ---\n"
            for match in glossaryMatches {
                let entry = match.entry
                prompt += "- [\(entry.category.rawValue.capitalized)] \(entry.originalTerm) -> \(entry.translation)\n"
            }
            prompt += "--- GLOSSARY END ---\n\n"
        }

        prompt += "Now, translate the following text:\n"
        prompt += "--- TEXT TO TRANSLATE START ---\n"
        prompt += text
        prompt += "\n--- TEXT TO TRANSLATE END ---"
        
        return prompt
    }
}
