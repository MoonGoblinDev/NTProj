//
//  EditorPane.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 17/06/25.
//


import SwiftUI
import STTextViewSwiftUI
import STTextView

struct EditorPane: View {
    // Bindings for the text content
    @Binding var sourceText: AttributedString
    @Binding var translatedText: AttributedString
    
    // Bindings for selection from the parent view model
    @Binding var sourceSelectionFromViewModel: NSRange?
    @Binding var translatedSelectionFromViewModel: NSRange?
    
    let isDisabled: Bool
    
    // Local state to drive the TextViews and prevent feedback loops
    @State private var localSourceSelection: NSRange?
    @State private var localTranslatedSelection: NSRange?
    
    private let textViewOptions: TextView.Options = [
        .showLineNumbers,
        .wrapLines,
        .highlightSelectedLine
    ]

    var body: some View {
        HSplitView {
            TextView(
                text: $sourceText,
                selection: $localSourceSelection, // Driven by local @State
                options: textViewOptions
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            TextView(
                text: $translatedText,
                selection: $localTranslatedSelection, // Driven by local @State
                options: textViewOptions
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(isDisabled)
        }
        // This block ensures the local state and the view model state are always in sync.
        .onAppear {
            localSourceSelection = sourceSelectionFromViewModel
            localTranslatedSelection = translatedSelectionFromViewModel
        }
        .onChange(of: localSourceSelection) { _, newSelection in
            // Update the view model when the user changes selection in the editor
            if sourceSelectionFromViewModel != newSelection {
                sourceSelectionFromViewModel = newSelection
            }
        }
        .onChange(of: sourceSelectionFromViewModel) { _, newSelection in
            // Update the editor when the view model's selection changes from elsewhere
            if localSourceSelection != newSelection {
                localSourceSelection = newSelection
            }
        }
        .onChange(of: localTranslatedSelection) { _, newSelection in
            // Update the view model when the user changes selection in the editor
            if translatedSelectionFromViewModel != newSelection {
                translatedSelectionFromViewModel = newSelection
            }
        }
        .onChange(of: translatedSelectionFromViewModel) { _, newSelection in
            // Update the editor when the view model's selection changes from elsewhere
            if localTranslatedSelection != newSelection {
                localTranslatedSelection = newSelection
            }
        }
    }
}
