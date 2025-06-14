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
        targetLanguage: String,
        preset: PromptPreset?
    ) -> String {
        let template = (preset?.prompt.isEmpty == false) ? preset!.prompt : PromptPreset.defaultPrompt

        var glossaryBlock = ""
        if !glossaryMatches.isEmpty {
            // Step 1: Get unique entries from all matches to avoid duplicates.
            let uniqueEntries = Set(glossaryMatches.map { $0.entry })

            // Step 2: Group the unique entries by their category.
            let groupedEntries = Dictionary(grouping: uniqueEntries, by: { $0.category })

            // Step 3: Build the formatted string from the grouped dictionary.
            glossaryBlock += "CRITICAL: You MUST use the following translations for specific terms. Do not deviate from them.\n"
            glossaryBlock += "--- GLOSSARY START ---\n"

            // Sort categories by their display name for consistent, alphabetical order.
            for category in groupedEntries.keys.sorted(by: { $0.displayName < $1.displayName }) {
                guard let entries = groupedEntries[category], !entries.isEmpty else { continue }
                
                // Add the category header.
                glossaryBlock += "[\(category.displayName)]\n"
                
                // Sort entries within the category alphabetically by the original term.
                for entry in entries.sorted(by: { $0.originalTerm < $1.originalTerm }) {
                    var line = "\(entry.originalTerm) -> \(entry.translation)"
                    // Append context description if it exists and is not empty.
                    if entry.contextDescription != "" {
                        line += " | Context: \(entry.contextDescription)"
                    }
                    glossaryBlock += "\(line)\n"
                }
                // Add a blank line after each category for readability.
                glossaryBlock += "\n"
            }
            
            // Remove the final blank line and add the end marker.
            glossaryBlock = glossaryBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            glossaryBlock += "\n--- GLOSSARY END ---\n\n"
        }

        var prompt = template
            .replacingOccurrences(of: "{{SOURCE_LANGUAGE}}", with: sourceLanguage)
            .replacingOccurrences(of: "{{TARGET_LANGUAGE}}", with: targetLanguage)
            .replacingOccurrences(of: "{{TEXT}}", with: text)

        // Handle optional glossary placeholder
        if template.contains("{{GLOSSARY}}") {
            prompt = prompt.replacingOccurrences(of: "{{GLOSSARY}}", with: glossaryBlock)
        } else if !glossaryBlock.isEmpty {
            // If the user's template doesn't include the placeholder, prepend the glossary.
            prompt = glossaryBlock + prompt
        }

        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
