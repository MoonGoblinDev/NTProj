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

    var body: some View {
        if let chapter = activeChapter, let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) {
            Form {
                Section("Chapter Details") {
                    LabeledContent("Title", value: chapter.title)

                    Picker("Status", selection: $project.chapters[chapterIndex].translationStatus) {
                        ForEach(Chapter.TranslationStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .onChange(of: project.chapters[chapterIndex].translationStatus) {
                        project.lastModifiedDate = Date()
                        projectManager.saveProject()
                    }

                    LabeledContent("Source Lines", value: "\(chapter.sourceLineCount)")
                    LabeledContent("Translated Lines", value: "\(chapter.translatedLineCount)")
                    LabeledContent("Word Count", value: "\(chapter.wordCount)")
                }
                
                Section("Last Translation Info") {
                    if let model = chapter.lastTranslationModel, !model.isEmpty {
                        LabeledContent("Model", value: model)
                        if let date = chapter.lastTranslatedDate {
                            LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let time = chapter.lastTranslationTime {
                            LabeledContent("Time", value: String(format: "%.2f s", time))
                        }
                        if let tokens = chapter.lastTranslationTokensUsed {
                            LabeledContent("Tokens", value: "\(tokens)")
                        }
                    } else if chapter.translatedContent?.isEmpty == false {
                        // Has content, but no LLM metadata (e.g., from manual edit)
                        LabeledContent("Source", value: "Manual")
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
                        
                        Text("Source: \(version.llmModel)")
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
            
            Button(action: {
                deleteVersion(version, in: chapter)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Delete this version")
        }
        .padding(.vertical, 4)
        .background(previewingVersionID == version.id ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut, value: previewingVersionID)
    }

    // MARK: - Core Action Methods

    private func saveCurrentAsVersion(chapter: Chapter, name: String) {
        let service = TranslationService()
        service.createVersionSnapshot(project: project, chapterID: chapter.id, name: name)
        projectManager.saveProject()
    }

    private func revertToVersion(_ versionToRevert: TranslationVersion, in chapter: Chapter) {
        stopPreviewing()
        
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        
        // Update the chapter's main content and metadata from the version being reverted to.
        project.chapters[chapterIndex].translatedContent = versionToRevert.content
        project.chapters[chapterIndex].lastTranslatedDate = versionToRevert.createdDate
        project.chapters[chapterIndex].lastTranslationModel = versionToRevert.llmModel
        project.chapters[chapterIndex].lastTranslationTime = versionToRevert.translationTime
        project.chapters[chapterIndex].lastTranslationTokensUsed = versionToRevert.tokensUsed
        
        // Update the live editor state
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
        
        // Any version can be deleted now.
        guard let chapterIndex = project.chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        
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
