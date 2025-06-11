//
//  AppContext.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI

/// A shared, observable object to manage app-wide state and actions.
/// This avoids race conditions by providing a single source of truth.
@MainActor
class AppContext: ObservableObject {
    
    /// When this value is set, any view observing it can react, such as by presenting a sheet.
    /// The `didSet` ensures that if we try to show the same item twice, the sheet still reappears.
    @Published var glossaryEntryToEditID: UUID? {
        didSet {
            // This logic helps if a user closes the sheet and clicks the same
            // link again. Without it, the value wouldn't "change" and the
            // .onChange modifier wouldn't fire a second time.
            if oldValue != nil && glossaryEntryToEditID != nil {
                isSheetPresented = false
                // A tiny delay allows the sheet to dismiss before re-presenting.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.isSheetPresented = true
                }
            } else {
                isSheetPresented = glossaryEntryToEditID != nil
            }
        }
    }
    
    /// A boolean flag that is directly controlled by the ID.
    /// Views will bind their .sheet modifier to this.
    @Published var isSheetPresented: Bool = false
}
