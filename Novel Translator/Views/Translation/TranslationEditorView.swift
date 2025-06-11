//
//  TranslationEditorView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI

/// A dedicated view for the side-by-side translation editor.
struct TranslationEditorView: View {
    // The chapter to get source text and metadata from.
    let chapter: Chapter
    
    // A binding to the translated text, managed by the parent's ViewModel.
    @Binding var translatedContent: String
    
    // Flag to disable the editor during streaming.
    let isDisabled: Bool
    
    var body: some View {
        HSplitView {
            // --- Left Panel: Source Text ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Source: \(chapter.project?.sourceLanguage ?? "")")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                TextEditor(text: .constant(chapter.rawContent))
                    .font(.system(.body, design: .serif))
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
            }
            
            // --- Right Panel: Translated Text ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Translation: \(chapter.project?.targetLanguage ?? "") (\(chapter.translationStatus.rawValue))")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                // Bind directly to the parent's state
                TextEditor(text: $translatedContent)
                    .font(.system(.body, design: .serif))
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .disabled(isDisabled) // Disable editing while streaming
            }
        }
        // The navigation title is specific to the editor, so it belongs here.
        .navigationTitle(chapter.title)
    }
}
