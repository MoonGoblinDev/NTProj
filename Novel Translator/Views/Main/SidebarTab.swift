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
    case search = "Search"
    case settings = "Settings"
    case stats = "Statistics"
    
    var icon: String {
        switch self {
        case .chapters: "book.pages.fill"
        case .glossary: "books.vertical.fill"
        case .search: "magnifyingglass"
        case .settings: "gear"
        case .stats: "chart.xyaxis.line"
        }
    }
}
