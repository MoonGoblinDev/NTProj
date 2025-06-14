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

extension String {
    /// A rough estimation of token count.
    /// This is not accurate and should be replaced with a proper tokenizer for specific models.
    /// A common rule of thumb is that 1 token is approximately 0.75 words.
    func estimateTokens() -> Int {
        let words = self.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        // Using the 4/3 multiplier for words-to-tokens.
        return Int(ceil(Double(words.count) * 4.0 / 3.0))
    }
}
