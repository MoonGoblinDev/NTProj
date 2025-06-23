//
//  GlossaryPopupView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 20/06/25.
//

import SwiftUI

struct GlossaryPopupView: View {
    // Using the same struct defined in EditorAreaView
    let info: EditorAreaView.GlossaryInfo
    
    let onOpenDetail: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(info.entry.category.displayName)")
                    .fontWeight(.bold)
                    .textSelection(.enabled)
                    .foregroundColor(info.entry.category.highlightColor)
                    
                    Text("\(info.entry.originalTerm) : \(info.entry.translation)")
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                
                
            }
            .padding(.leading, 8)
            
            Spacer()
            
            Button(action: onOpenDetail) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help("Edit Glossary Entry")
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary, .tertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(minWidth: 250, maxWidth: 400)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .onAppear(perform: setAutoDismissTimer)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
    
    private func setAutoDismissTimer() {
        // Automatically dismiss the popup after 5 seconds if the user isn't interacting with it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Only dismiss if the user is not hovering over the popup.
            if !isHovering {
                withAnimation(.easeInOut) { onDismiss() }
            }
        }
    }
}
