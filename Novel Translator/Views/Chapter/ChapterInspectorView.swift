//
//  ChapterInspectorView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 29/06/25.
//

// FILE: Novel Translator/Views/Chapter/ChapterInspectorView.swift
import SwiftUI

struct ChapterInspectorView: View {
    @ObservedObject var project: TranslationProject
    @ObservedObject var projectManager: ProjectManager
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    
    // State for creating a manual version
    @State private var isAddVersionAlertPresented = false
    @State private var newVersionName = ""
    
    private var activeChapter: Chapter? {
        workspaceViewModel.activeChapter
    }
    
    private var currentVersion: TranslationVersion? {
        activeChapter?.translationVersions.first(where: { $0.isCurrentVersion })
    }

    var body: some View {
        if let chapter = activeChapter {
            Form {
                Section("Chapter Details") {
                    LabeledContent("Title", value: chapter.title)
                    LabeledContent("Status", value: chapter.translationStatus.rawValue)
                    LabeledContent("Source Lines", value: "\(chapter.sourceLineCount)")
                    LabeledContent("Translated Lines", value: "\(chapter.translatedLineCount)")
                    LabeledContent("Word Count", value: "\(chapter.wordCount)")
                }
                
                Section("Current Translation Info") {
                    if let version = currentVersion {
                        LabeledContent("Model", value: version.llmModel)
                        if let date = chapter.lastTranslatedDate {
                            LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let time = version.translationTime {
                            LabeledContent("Time", value: String(format: "%.2f s", time))
                        }
                        if let tokens = version.tokensUsed {
                            LabeledContent("Tokens", value: "\(tokens)")
                        }
                    } else {
                        Text("Not translated yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    if chapter.translationVersions.isEmpty {
                        Text("No versions saved.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                    } else {
                        List {
                            ForEach(chapter.translationVersions.sorted(by: { $0.createdDate > $1.createdDate })) { version in
                                versionRow(for: version, in: chapter)
                            }
                        }
                        .listStyle(.plain)
                        .frame(minHeight: 150)
                    }
                } header: {
                    HStack {
                        Text("Translation Versions")
                            .font(.headline)
                        Spacer()
                        Button {
                            newVersionName = "Manual Snapshot - \(Date().formatted(date: .abbreviated, time: .shortened))"
                            isAddVersionAlertPresented = true
                        } label: {
                            Label("Add Current as Version", systemImage: "plus.circle")
                        }
                        .labelsHidden()
                        .help("Save current translation as a named version")
                        .disabled(chapter.translatedContent?.isEmpty ?? true)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .alert("Add Translation Version", isPresented: $isAddVersionAlertPresented) {
                TextField("Version Name", text: $newVersionName)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    saveCurrentAsVersion(chapter: chapter, name: newVersionName)
                }
            }
        } else {
            ContentUnavailableView("No Chapter Selected", systemImage: "doc.text.magnifyingglass")
        }
    }
    
    @ViewBuilder
    private func versionRow(for version: TranslationVersion, in chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(version.name ?? "Version \(version.versionNumber)")
                    .fontWeight(version.isCurrentVersion ? .bold : .regular)
                if version.isCurrentVersion {
                    Text("(Current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(version.createdDate.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Model: \(version.llmModel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Revert to this Version") {
                revertToVersion(version, in: chapter)
            }
            .disabled(version.isCurrentVersion)
            
            Button("Delete Version", role: .destructive) {
                deleteVersion(version, in: chapter)
            }
            .disabled(version.isCurrentVersion) // Can't delete the current version
        }
    }
    
    private func saveCurrentAsVersion(chapter: Chapter, name: String) {
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }),
              let translatedContent = project.chapters[chapterIndex].translatedContent,
              !translatedContent.isEmpty else { return }

        // Create new version
        let newVersion = TranslationVersion(
            versionNumber: (project.chapters[chapterIndex].translationVersions.map(\.versionNumber).max() ?? 0) + 1,
            content: translatedContent,
            llmModel: "Manual Snapshot",
            isCurrentVersion: false, // It's a snapshot, not the active translation
            name: name
        )
        project.chapters[chapterIndex].translationVersions.append(newVersion)
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
    
    private func revertToVersion(_ versionToRevert: TranslationVersion, in chapter: Chapter) {
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        
        // 1. Deactivate the old current version
        if let oldCurrentIndex = project.chapters[chapterIndex].translationVersions.firstIndex(where: { $0.isCurrentVersion }) {
            project.chapters[chapterIndex].translationVersions[oldCurrentIndex].isCurrentVersion = false
        }
        
        // 2. Activate the new current version
        if let newCurrentIndex = project.chapters[chapterIndex].translationVersions.firstIndex(where: { $0.id == versionToRevert.id }) {
            project.chapters[chapterIndex].translationVersions[newCurrentIndex].isCurrentVersion = true
        }
        
        // 3. Update the chapter's main translated content
        project.chapters[chapterIndex].translatedContent = versionToRevert.content
        
        // 4. Update the editor state if the chapter is open
        if let editorState = workspaceViewModel.editorStates[chapter.id] {
            editorState.updateTranslation(newText: versionToRevert.content)
        }
        
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }

    private func deleteVersion(_ versionToDelete: TranslationVersion, in chapter: Chapter) {
        guard !versionToDelete.isCurrentVersion,
              let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        
        project.chapters[chapterIndex].translationVersions.removeAll { $0.id == versionToDelete.id }
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }
}
