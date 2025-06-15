//
//  GlossaryResponseWrapper.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 17/06/25.
//

import Foundation

/// A flexible, robust wrapper to decode an array of `GlossaryEntry` from a model's JSON response.
///
/// This decoder can handle two common formats:
/// 1. A direct JSON array: `[ { ... }, { ... } ]`
/// 2. An array nested within a JSON object under any key: `{ "any_key": [ { ... }, { ... } ] }`
///
/// This resilience is crucial because LLMs can sometimes ignore specific key-naming instructions.
struct GlossaryResponseWrapper: Decodable {
    let entries: [GlossaryEntry]

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        // First, try to decode as a direct top-level array.
        if let topLevelEntries = try? [GlossaryEntry](from: decoder) {
            self.entries = topLevelEntries
            return
        }
        
        // If that fails, assume it's an object and find the first key that holds the array.
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        for key in container.allKeys {
            if let entries = try? container.decode([GlossaryEntry].self, forKey: key) {
                self.entries = entries
                return
            }
        }
        
        // If no array is found at the top level or nested, the format is unsupported.
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Could not find a top-level array or an array nested under a key in the JSON response.")
        )
    }
}
