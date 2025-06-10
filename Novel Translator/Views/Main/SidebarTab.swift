//
//  SidebarTab.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

// This enum is now public (internal by default) and can be shared by multiple views.
enum SidebarTab: String, CaseIterable {
    case chapters = "Chapters"
    case glossary = "Glossary"
    case settings = "Settings"
    case stats = "Statistics"
    
    var icon: String {
        switch self {
        case .chapters: "list.bullet"
        case .glossary: "text.book.closed.fill"
        case .settings: "gear"
        case .stats: "chart.bar.xaxis"
        }
    }
}
