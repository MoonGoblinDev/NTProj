//
//  AppContext.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI


@MainActor
class AppContext: ObservableObject {
    

    @Published var glossaryEntryToEditID: UUID? {
        didSet {
            if oldValue != nil && glossaryEntryToEditID != nil {
                isSheetPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.isSheetPresented = true
                }
            } else {
                isSheetPresented = glossaryEntryToEditID != nil
            }
        }
    }
    

    @Published var isSheetPresented: Bool = false
    @Published var searchResultToHighlight: SearchResultItem?
}
