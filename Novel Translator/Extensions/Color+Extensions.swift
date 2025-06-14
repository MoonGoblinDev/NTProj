//
//  Color+Extensions.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 11/06/25.
//

import SwiftUI

extension Color {
    // A custom gold color for highlighting glossary terms.
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    // Category-specific highlight colors
    static let glossaryCharacter = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let glossaryPlace = Color.green
    static let glossaryEvent = Color.orange
    static let glossaryObject = Color.purple
    static let glossaryConcept = Color.teal
    static let glossaryOrganization = Color.brown
    static let glossaryOther = Color.blue
}
