//
//  AppContext.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI

@MainActor
class AppContext: ObservableObject {
    
    /// This property is used to signal which glossary entry's detail view should be shown.
    /// Setting it will trigger the sheet presentation logic.
    @Published var glossaryEntryIDForDetail: UUID? {
        didSet {
            if oldValue != nil && glossaryEntryIDForDetail != nil {
                isGlossaryDetailSheetPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.isGlossaryDetailSheetPresented = true
                }
            } else {
                isGlossaryDetailSheetPresented = glossaryEntryIDForDetail != nil
            }
        }
    }
    
    @Published var isGlossaryDetailSheetPresented: Bool = false
    @Published var searchResultToHighlight: SearchResultItem?
    
    // State for the inspector sidebar
    @Published var isInspectorVisible: Bool = false
    @Published var selectedInspectorTab: InspectorTab = .chapter // Default to chapter tab
}
