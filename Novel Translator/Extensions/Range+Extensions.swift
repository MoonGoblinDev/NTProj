//
//  Range+Extensions.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 13/06/25.
//
import Foundation
import Tiktoken

extension Range where Bound == String.Index {
    func toNSRange(in string: String) -> NSRange {
        // Check if the range bounds are valid for the string
        guard lowerBound >= string.startIndex && upperBound <= string.endIndex else {
            return NSRange(location: 0, length: 0)
        }
        
        return NSRange(self, in: string)
    }
}
