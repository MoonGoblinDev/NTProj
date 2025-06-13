//
//  ChapterTabsView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 13/06/25.
//

import SwiftUI
import SwiftData

struct ChapterTabsView: View {
    @Bindable var workspaceViewModel: WorkspaceViewModel
    let projects: [TranslationProject]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(workspaceViewModel.openChapterIDs, id: \.self) { chapterID in
                    if let chapter = chapter(for: chapterID) {
                        ChapterTabItem(
                            chapter: chapter,
                            isActive: chapterID == workspaceViewModel.activeChapterID,
                            hasUnsavedChanges: workspaceViewModel.editorStates[chapterID]?.hasUnsavedChanges ?? false,
                            onSelect: {
                                workspaceViewModel.activeChapterID = chapterID
                            },
                            onClose: {
                                workspaceViewModel.closeChapter(id: chapterID)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 6)
        .frame(height: 38)
        .background(Material.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private func chapter(for id: PersistentIdentifier) -> Chapter? {
        for project in projects {
            if let chapter = project.chapters.first(where: { $0.id == id }) {
                return chapter
            }
        }
        return nil
    }
}

fileprivate struct ChapterTabItem: View {
    let chapter: Chapter
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(chapter.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .padding(.leading, 12)

            closeButton
                .padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity)
        .background(
            isActive ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.15) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var closeButton: some View {
        ZStack {
            // Unsaved changes indicator (a filled circle)
            if hasUnsavedChanges && !isHovered {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 14, height: 14)
            }
            
            // The 'x' close button, visible on hover
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 16)
                .background(
                    .secondary.opacity(0.2),
                    in: Circle()
                )
                .opacity(isHovered ? 1 : 0)
        }
        .onTapGesture(perform: onClose)
    }
}
