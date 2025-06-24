//
//  RAGService.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 21/06/25.
//

import Foundation

/// A text chunk used for Retrieval-Augmented Generation.
struct TextChunk: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let chapterID: UUID
    let chapterTitle: String
    let chapterNumber: Int
}

class RAGService {
    
    /// Finds the most relevant chunks of text from the project to answer a user's query.
    /// - Parameters:
    ///   - project: The full translation project.
    ///   - query: The user's question.
    ///   - maxChunks: The maximum number of context chunks to return.
    /// - Returns: An array of the most relevant `TextChunk`s.
    func retrieveRelevantChunks(from project: TranslationProject, for query: String, maxChunks: Int = 5) -> [TextChunk] {
        // A more advanced implementation would use vector embeddings. For now, we use a keyword-based search.
        let queryKeywords = Set(
            query.lowercased()
                .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
                .filter { $0.count > 2 }
                .map(String.init) // Convert Substring to String
        )
        guard !queryKeywords.isEmpty else { return [] }
        
        var allChunks: [TextChunk] = []
        
        // Create overlapping chunks from both source and translated text to better capture context.
        for chapter in project.chapters.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            // A more robust chunking strategy using a sliding window.
            // This helps capture context that spans across multiple lines.
            let chunkSize = 5 // The number of lines in each chunk.
            let chunkOverlap = 2 // The number of lines to overlap between chunks.
            let strideBy = max(1, chunkSize - chunkOverlap)

            // Helper function to create overlapping chunks from a list of lines
            let createOverlappingChunks = { (lines: [String]) -> [String] in
                var chunks: [String] = []
                guard !lines.isEmpty else { return chunks }

                for i in stride(from: 0, to: lines.count, by: strideBy) {
                    let end = min(i + chunkSize, lines.count)
                    if i < end {
                        let chunkContent = lines[i..<end].joined(separator: "\n")
                        if !chunkContent.isEmpty {
                            chunks.append(chunkContent)
                        }
                    }
                }
                return chunks
            }

            // Process raw content
            let rawLines = chapter.rawContent.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let rawChunks = createOverlappingChunks(rawLines)
            for chunkContent in rawChunks {
                allChunks.append(TextChunk(content: chunkContent, chapterID: chapter.id, chapterTitle: chapter.title, chapterNumber: chapter.chapterNumber))
            }
            
            // Process translated content
            if let translated = chapter.translatedContent {
                let translatedLines = translated.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let translatedChunks = createOverlappingChunks(translatedLines)
                for chunkContent in translatedChunks {
                    allChunks.append(TextChunk(content: chunkContent, chapterID: chapter.id, chapterTitle: chapter.title, chapterNumber: chapter.chapterNumber))
                }
            }
        }
        
        // Score each chunk based on keyword intersection.
        let scoredChunks = allChunks.map { chunk in
            let chunkWords = Set(chunk.content.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init))
            let score = queryKeywords.intersection(chunkWords).count
            return (chunk, score)
        }.filter { $0.1 > 0 } // Only keep chunks with at least one match.
        
        let sortedChunks = scoredChunks.sorted { $0.1 > $1.1 }.map { $0.0 }
        
        // Deduplicate chunks based on content to avoid sending the same paragraph twice.
        var uniqueChunks: [TextChunk] = []
        var seenContent = Set<String>()
        for chunk in sortedChunks {
            if !seenContent.contains(chunk.content) {
                uniqueChunks.append(chunk)
                seenContent.insert(chunk.content)
            }
        }
        
        return Array(uniqueChunks.prefix(maxChunks))
    }
    
    /// Builds the final prompt for the LLM, including the retrieved context.
    /// - Parameters:
    ///   - query: The user's original question.
    ///   - chunks: The relevant context chunks found by `retrieveRelevantChunks`.
    /// - Returns: A formatted string ready to be sent to the LLM.
    func generatePrompt(query: String, chunks: [TextChunk]) -> String {
        guard !chunks.isEmpty else {
            // Fallback prompt if no context is found.
            return """
            You are a helpful assistant for a novel translator. The user has a question, but no specific context from the novel could be found. Answer the question generally, but state that you could not find specific information in the text.
            
            User's Question: \(query)
            Answer:
            """
        }
        
        let contextString = chunks.map { chunk in
            "From Chapter \(chunk.chapterNumber) (\(chunk.chapterTitle)):\n\"\(chunk.content)\""
        }.joined(separator: "\n\n---\n\n")
        
        return """
        You are a helpful assistant for a novel translator. Answer the user's question based *only* on the provided context from the novel. Quote from the text if it helps. If the context doesn't contain the answer, state that clearly.

        --- CONTEXT FROM NOVEL ---
        \(contextString)
        --- END OF CONTEXT ---

        User's Question: \(query)

        Answer:
        """
    }
}
