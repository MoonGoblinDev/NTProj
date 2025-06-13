//
//  Range+Extensions.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 13/06/25.
//
import Foundation

extension Range where Bound == String.Index {
    func toNSRange(in string: String) -> NSRange {
        return NSRange(self, in: string)
    }
}
