//
//  PromptBuilder.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

class PromptBuilder {
    
    // MARK: - Public Methods
    
    func buildTranslationPrompt(
        text: String,
        glossaryMatches: [GlossaryMatch],
        sourceLanguage: String,
        targetLanguage: String,
        preset: PromptPreset?,
        config: TranslationProject.TranslationConfig
    ) -> String {
        var promptComponents: [String] = []
        
        // 1. Build the one-shot example block if provided
        if let exampleBlock = buildExampleBlock(from: preset, config: config) {
            promptComponents.append(exampleBlock)
        }
        
        // 2. Build the main prompt body from the template
        let template = (preset?.prompt.isEmpty == false) ? preset!.prompt : PromptPreset.defaultPrompt
        let glossaryBlock = buildGlossaryBlock(from: glossaryMatches)
        
        // 3. Handle line-sync pre-processing if enabled
        let textToTranslate: String
        if config.forceLineCountSync {
            promptComponents.append(getLineSyncInstruction())
            textToTranslate = preprocessTextForLineSync(text: text)
        } else {
            textToTranslate = text
        }
        
        var mainPrompt = template
            .replacingOccurrences(of: "{{SOURCE_LANGUAGE}}", with: sourceLanguage)
            .replacingOccurrences(of: "{{TARGET_LANGUAGE}}", with: targetLanguage)
            .replacingOccurrences(of: "{{TEXT}}", with: textToTranslate)

        // Handle optional glossary placeholder
        if template.contains("{{GLOSSARY}}") {
            mainPrompt = mainPrompt.replacingOccurrences(of: "{{GLOSSARY}}", with: glossaryBlock)
        } else if !glossaryBlock.isEmpty {
            mainPrompt = glossaryBlock + mainPrompt
        }
        
        promptComponents.append(mainPrompt)
        
        return promptComponents.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func buildGlossaryExtractionPrompt(
        sourceText: String,
        translatedText: String,
        existingGlossary: [GlossaryEntry],
        sourceLanguage: String,
        targetLanguage: String,
        categoriesToExtract: [GlossaryEntry.GlossaryCategory],
        additionalQuery: String,
        fillContext: Bool
    ) -> String {
        let existingGlossaryText = existingGlossary
            .map { "- \($0.originalTerm) -> \($0.translation)" }
            .joined(separator: "\n")
        
        let allCategoryValues = GlossaryEntry.GlossaryCategory.allCases.map { $0.rawValue }.joined(separator: ", ")

        var instructions = """
        You are a linguistic expert tasked with expanding a glossary for a novel translation project. Analyze the provided source text and its professional translation. Identify new, important, or recurring terms (such as characters, places, special abilities, items, or concepts) that are NOT already in the existing glossary list.
        
        ---
        
        **CRITICAL INSTRUCTIONS:**
        1.  **DO NOT** extract terms that are already present in the "Existing Glossary" list.
        2.  Focus on proper nouns, unique concepts, or recurring objects. Avoid common words.
        3.  The `contextDescription` should be concise and based *only* on the provided texts.
        4.  You **MUST** return your findings as a JSON object. This object must contain a single key, "entries", which holds an array of glossary objects.
        5.  Each object in the "entries" array **MUST** conform to this schema:
            - `originalTerm` (string, required): The term in the source language.
            - `translation` (string, required): The term in the target language.
            - `category` (string, enum, required): The category of the term. Must be one of: \(allCategoryValues).
            - `contextDescription` (string, optional): A brief explanation.
        6.  If no new terms are found, you **MUST** return an empty array like this: `{"entries": []}`.
        """
        
        if categoriesToExtract.count < GlossaryEntry.GlossaryCategory.allCases.count {
            let categoryList = categoriesToExtract.map { $0.rawValue }.joined(separator: ", ")
            instructions += "\n7.  Only extract terms belonging to the following categories: \(categoryList)."
        }
        
        if !fillContext {
            instructions += "\n8.  The `contextDescription` field for all extracted items **MUST** be an empty string."
        }
        
        if !additionalQuery.isEmpty {
            instructions += "\n9.  Follow this additional instruction carefully: \(additionalQuery)"
        }

        let prompt = """
        \(instructions)
        
        ---
        
        **EXISTING GLOSSARY (DO NOT EXTRACT THESE):**
        \(existingGlossaryText.isEmpty ? "None" : existingGlossaryText)
        
        ---
        
        **SOURCE TEXT (\(sourceLanguage)):**
        \(sourceText)
        
        ---
        
        **TRANSLATED TEXT (\(targetLanguage)):**
        \(translatedText)
        
        ---
        
        Now, provide the JSON object with the "entries" key.
        """
        
        return prompt
    }

    /// Public method to clean the LLM's output if line-syncing was used.
    public func postprocessLineSync(text: String) -> String {
        return postprocessTextForLineSync(text: text)
    }

    // MARK: - Private Helpers
    
    private func getLineSyncInstruction() -> String {
        return """
        CRITICAL INSTRUCTION: The following text has been formatted with line markers (e.g., [L1], [L2]). You MUST translate the text for each line and reproduce the exact same line markers in your output. Empty lines must be preserved. The number of lines in your translation must exactly match the number of lines in the source.
        
        Example:
        [L1] source text -> [L1] translation text
        [L2] -> [L2]
        [L3] source text -> [L3] translation text
        
        """
    }

    private func preprocessTextForLineSync(text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.enumerated().map { "[L\($0.offset + 1)] \($0.element)" }.joined(separator: "\n")
    }
    
    private func postprocessTextForLineSync(text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let pattern = #"^\[L\d+\] ?"# // Regex to find "[L...]" at the start of a line, with an optional space.

        return lines.map { line in
            line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }.joined(separator: "\n")
    }
    
    private func buildExampleBlock(from preset: PromptPreset?, config: TranslationProject.TranslationConfig) -> String? {
        guard let preset = preset, preset.provideExample, !preset.exampleRawText.isEmpty else { return nil }
        
        let rawExample = config.forceLineCountSync ? preprocessTextForLineSync(text: preset.exampleRawText) : preset.exampleRawText
        let translatedExample = config.forceLineCountSync ? preprocessTextForLineSync(text: preset.exampleTranslatedText) : preset.exampleTranslatedText
        
        return """
        Here is an example of the desired translation style and format. Follow it carefully.
        --- EXAMPLE START ---
        [Source]:
        \(rawExample)
        
        [Translation]:
        \(translatedExample)
        --- EXAMPLE END ---
        """
    }

    private func buildGlossaryBlock(from glossaryMatches: [GlossaryMatch]) -> String {
        guard !glossaryMatches.isEmpty else { return "" }
        
        var glossaryBlock = ""
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
                if !entry.contextDescription.isEmpty {
                    line += " | Context: \(entry.contextDescription)"
                }
                glossaryBlock += "\(line)\n"
            }
            glossaryBlock += "\n"
        }
        
        glossaryBlock = glossaryBlock.trimmingCharacters(in: .whitespacesAndNewlines)
        glossaryBlock += "\n--- GLOSSARY END ---\n\n"
        
        return glossaryBlock
    }
}
