//
//  JSONCoders.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 14/06/25.
//

import Foundation

extension JSONEncoder {
    static var prettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }
}
