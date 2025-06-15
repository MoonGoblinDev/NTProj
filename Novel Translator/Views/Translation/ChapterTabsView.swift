import SwiftUI

struct ChapterTabsView: View {
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    let project: TranslationProject

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
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
        }
        .padding(0.5)
        .frame(height: 38)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private func chapter(for id: UUID) -> Chapter? {
        return project.chapters.first(where: { $0.id == id })
    }
}

fileprivate struct ChapterTabItem: View {
    let chapter: Chapter
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    @State private var exitiIsHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text("􁜿")
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundColor(hasUnsavedChanges ? Color.unsaved : .primary)
                .padding(.leading, 15)
            
            Text(chapter.title)
                .font(.system(size: 13))
                .lineLimit(1)

            closeButton
                .padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity)
        .background(
            isActive ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.15) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20 , style: .continuous))
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
            
            // The 'x' close button, visible on hover
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 16)
                .background(
                    .secondary.opacity(0.2),
                    in: Circle()
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        exitiIsHovered = hovering
                    }
                }
                .opacity(isHovered ? 1 : 0)
                .scaleEffect(exitiIsHovered ? 1.2 : 1)
        }
        .onTapGesture(perform: onClose)
    }
}
