//
//  GlossaryMatch.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import Foundation

struct GlossaryMatch {
    let entry: GlossaryEntry
    let range: Range<String.Index>
    let matchedAlias: String? // Which alias was matched, if any
}
