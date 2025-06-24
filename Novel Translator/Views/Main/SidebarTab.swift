//
//  SidebarTab.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation


enum SidebarTab: String, CaseIterable {
    case chapters = "􀤞"
    case glossary = "􀅶"
    case search = "􀊫"
    case settings = "􀣋"
    case stats = "􁂥"
    
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
