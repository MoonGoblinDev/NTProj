//
//  EditorPane.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 17/06/25.
//

// Create this new file or add it at the bottom of TranslationEditorView.swift
// FILE: Novel Translator/Views/Translation/EditorPane.swift (or similar)

import SwiftUI
import STTextViewSwiftUI
import STTextView

/// A highly isolated view containing only the HSplitView and the two STTextView editors.
/// This prevents re-renders from parent "chrome" (like token counters) from affecting the editors.
struct EditorPane: View {
    @Binding var sourceText: AttributedString
    @Binding var translatedText: AttributedString
    @Binding var sourceSelection: NSRange?
    @Binding var translatedSelection: NSRange?
    
    let isDisabled: Bool
    
    private let textViewOptions: TextView.Options = [
        .showLineNumbers,
        .wrapLines,
        .highlightSelectedLine
    ]

    var body: some View {
        HSplitView {
            TextView(
                text: $sourceText,
                selection: $sourceSelection,
                options: textViewOptions
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            TextView(
                text: $translatedText,
                selection: $translatedSelection,
                options: textViewOptions
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(isDisabled)
        }
    }
}
