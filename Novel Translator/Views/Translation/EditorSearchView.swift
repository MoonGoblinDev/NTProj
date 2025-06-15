//
//  EditorSearchView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 15/06/25.
//

import SwiftUI

struct EditorSearchView: View {
    @Binding var searchQuery: String
    let totalResults: Int
    @Binding var currentResultIndex: Int?
    
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $searchQuery)
                .textFieldStyle(.plain)
                .frame(width: 150)

            Text(resultText)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Button(action: onFindPrevious) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(totalResults == 0)

            Button(action: onFindNext) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(totalResults == 0)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var resultText: String {
        if searchQuery.isEmpty {
            return ""
        }
        if totalResults == 0 {
            return "No Results"
        }
        let currentIndexDisplay = (currentResultIndex ?? -1) + 1
        return "\(currentIndexDisplay) of \(totalResults)"
    }
}
