// FILE: Novel Translator/Views/Chapter/ChapterInspectorView.swift
import SwiftUI

struct ChapterInspectorView: View {
    @ObservedObject var project: TranslationProject
    @ObservedObject var projectManager: ProjectManager
    @ObservedObject var workspaceViewModel: WorkspaceViewModel

    // State for creating a manual version
    @State private var isAddVersionAlertPresented = false
    @State private var newVersionName = ""

    // State for version previewing
    @State private var previewingVersionID: UUID?
    @State private var prePreviewTranslatedText: AttributedString?

    private var activeChapter: Chapter? {
        workspaceViewModel.activeChapter
    }

    private var currentVersion: TranslationVersion? {
        activeChapter?.translationVersions.first(where: { $0.isCurrentVersion })
    }

    var body: some View {
        // Use if-let with chapterIndex for safe binding
        if let chapter = activeChapter, let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) {
            Form {
                Section("Chapter Details") {
                    LabeledContent("Title", value: chapter.title)

                    // MODIFICATION: Replaced LabeledContent with an editable Picker
                    Picker("Status", selection: $project.chapters[chapterIndex].translationStatus) {
                        ForEach(Chapter.TranslationStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .onChange(of: project.chapters[chapterIndex].translationStatus) {
                        // Save changes whenever the status is modified
                        project.lastModifiedDate = Date()
                        projectManager.saveProject()
                    }

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
                        VStack {
                            // Add a button to stop previewing if a preview is active
                            if previewingVersionID != nil {
                                HStack {
                                    Button(action: stopPreviewing) {
                                        Label("Stop Preview", systemImage: "arrow.uturn.backward.circle.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.gray)
                                }
                                .padding(.bottom, 4)
                            }
                            
                            List {
                                ForEach(chapter.translationVersions.sorted(by: { $0.createdDate > $1.createdDate })) { version in
                                    versionRow(for: version, in: chapter)
                                }
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
            .onChange(of: workspaceViewModel.activeChapterID) { _, _ in
                // When chapter changes, stop any active preview to avoid confusion
                stopPreviewing()
            }
        } else {
            ContentUnavailableView("No Chapter Selected", systemImage: "doc.text.magnifyingglass")
        }
    }

    @ViewBuilder
    private func versionRow(for version: TranslationVersion, in chapter: Chapter) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                togglePreview(for: version)
            }) {
                HStack(spacing: 8) {
                    if previewingVersionID == version.id {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.accentColor)
                            .transition(.opacity.combined(with: .scale))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(version.name ?? "Version \(version.versionNumber)")
                        
                        Text("Model: \(version.llmModel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Spacer()

            Button(action: {
                revertToVersion(version, in: chapter)
            }) {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.plain)
            .help("Revert to this version")
            .disabled(version.isCurrentVersion)
            
            Button(action: {
                deleteVersion(version, in: chapter)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Delete this version")
            .disabled(version.isCurrentVersion)
        }
        .padding(.vertical, 4)
        .background(previewingVersionID == version.id ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut, value: previewingVersionID)
    }

    // MARK: - Core Action Methods

    private func saveCurrentAsVersion(chapter: Chapter, name: String) {
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }),
              let translatedContent = project.chapters[chapterIndex].translatedContent,
              !translatedContent.isEmpty else { return }

        let newVersion = TranslationVersion(
            versionNumber: (project.chapters[chapterIndex].translationVersions.map(\.versionNumber).max() ?? 0) + 1,
            content: translatedContent,
            llmModel: "Manual Snapshot",
            isCurrentVersion: false,
            name: name
        )
        project.chapters[chapterIndex].translationVersions.append(newVersion)
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }

    private func revertToVersion(_ versionToRevert: TranslationVersion, in chapter: Chapter) {
        stopPreviewing()
        
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        
        if let oldCurrentIndex = project.chapters[chapterIndex].translationVersions.firstIndex(where: { $0.isCurrentVersion }) {
            project.chapters[chapterIndex].translationVersions[oldCurrentIndex].isCurrentVersion = false
        }
        
        if let newCurrentIndex = project.chapters[chapterIndex].translationVersions.firstIndex(where: { $0.id == versionToRevert.id }) {
            project.chapters[chapterIndex].translationVersions[newCurrentIndex].isCurrentVersion = true
        }
        
        project.chapters[chapterIndex].translatedContent = versionToRevert.content
        
        if let editorState = workspaceViewModel.editorStates[chapter.id] {
            editorState.updateTranslation(newText: versionToRevert.content)
        }
        
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }

    private func deleteVersion(_ versionToDelete: TranslationVersion, in chapter: Chapter) {
        if previewingVersionID == versionToDelete.id {
            stopPreviewing()
        }
        
        guard !versionToDelete.isCurrentVersion,
              let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        
        project.chapters[chapterIndex].translationVersions.removeAll { $0.id == versionToDelete.id }
        project.lastModifiedDate = Date()
        projectManager.saveProject()
    }

    // MARK: - Preview Logic

    private func togglePreview(for version: TranslationVersion) {
        if previewingVersionID == version.id {
            stopPreviewing()
        } else {
            startPreviewing(version: version)
        }
    }

    private func startPreviewing(version: TranslationVersion) {
        guard let editorState = workspaceViewModel.activeEditorState else { return }

        if prePreviewTranslatedText == nil {
            prePreviewTranslatedText = editorState.translatedAttributedText
        }
        
        previewingVersionID = version.id
        
        editorState.updateTranslation(newText: version.content)
    }

    private func stopPreviewing() {
        guard let editorState = workspaceViewModel.activeEditorState, previewingVersionID != nil else {
            return
        }
        
        if let originalText = prePreviewTranslatedText {
            editorState.translatedAttributedText = originalText
        }
        
        previewingVersionID = nil
        prePreviewTranslatedText = nil
    }
}
