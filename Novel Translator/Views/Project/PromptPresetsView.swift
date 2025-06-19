import SwiftUI

struct PromptPresetsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var projectManager: ProjectManager

    @State private var selectedPresetID: UUID?

    private var sortedPresets: [PromptPreset] {
        projectManager.settings.promptPresets.sorted { $0.createdDate < $1.createdDate }
    }
    
    private var selectedPresetBinding: Binding<PromptPreset>? {
        guard let selectedPresetID = selectedPresetID,
              let index = projectManager.settings.promptPresets.firstIndex(where: { $0.id == selectedPresetID }) else {
            return nil
        }
        return $projectManager.settings.promptPresets[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                VStack(spacing: 0) {
                    List(selection: $selectedPresetID) {
                        ForEach(sortedPresets) { preset in
                            Text(preset.name)
                                .tag(preset.id as UUID?)
                        }
                        .onDelete(perform: deletePresets)
                    }
                    .listStyle(.sidebar)
                    
                    Divider()
                    
                    HStack {
                        Spacer()
                        Button(action: addPreset) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    .frame(height: 36)
                    .background(.background.secondary)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 400)
            } detail: {
                if let presetBinding = selectedPresetBinding {
                    PromptPresetDetailView(preset: presetBinding, projectManager: projectManager)
                } else {
                    ContentUnavailableView("No Preset Selected", systemImage: "wand.and.stars", description: Text("Select a preset from the list or create a new one."))
                }
            }
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 500)
        .onAppear {
            if selectedPresetID == nil {
                selectedPresetID = sortedPresets.first?.id
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    projectManager.saveSettings()
                    dismiss()
                }
            }
        }
    }
    
    private func addPreset() {
        let newPreset = PromptPreset(name: "New Preset", prompt: PromptPreset.defaultPrompt)
        projectManager.settings.promptPresets.append(newPreset)
        selectedPresetID = newPreset.id
    }
    
    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            let presetToDelete = sortedPresets[index]
            if projectManager.settings.selectedPromptPresetID == presetToDelete.id {
                projectManager.settings.selectedPromptPresetID = nil
            }
            projectManager.settings.promptPresets.removeAll(where: { $0.id == presetToDelete.id })
        }
    }
}

fileprivate struct PromptPresetDetailView: View {
    @Binding var preset: PromptPreset
    @ObservedObject var projectManager: ProjectManager
    
    var body: some View {
        Form {
            Section {
                TextField("Preset Name", text: $preset.name)
            }
            
            Section("Translation Prompt") {
                TextEditor(text: $preset.prompt)
                    .font(.body.monospaced())
                    .frame(minHeight: 300, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                
                HStack {
                    Spacer()
                    TokenCounterView(text: preset.prompt, projectManager: projectManager, autoCount: true)
                }
            }
            
            // --- NEW SECTION for One-Shot Example ---
            Section("One-Shot Example (Optional)") {
                Toggle("Provide example translation", isOn: $preset.provideExample)
                
                if preset.provideExample {
                    HSplitView {
                        VStack(alignment: .leading) {
                            Text("Example Raw Text").font(.headline)
                            TextEditor(text: $preset.exampleRawText)
                                .frame(minHeight: 100, maxHeight: .infinity)
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Example Translated Text").font(.headline)
                            TextEditor(text: $preset.exampleTranslatedText)
                                .frame(minHeight: 100, maxHeight: .infinity)
                                .cornerRadius(8)
                        }
                    }
                    .frame(height: 200)
                }
            }

            Section("Available Placeholders") {
                Text("Use these placeholders in your prompt above:")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("`{{SOURCE_LANGUAGE}}` - The project's source language.").font(.callout)
                    Text("`{{TARGET_LANGUAGE}}` - The project's target language.").font(.callout)
                    Text("`{{GLOSSARY}}` - A formatted block of relevant glossary terms.").font(.callout)
                    Text("`{{TEXT}}` - The raw chapter text to be translated.").font(.callout)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: preset.name) { _, _ in preset.lastModifiedDate = Date() }
        .onChange(of: preset.prompt) { _, _ in preset.lastModifiedDate = Date() }
        .onChange(of: preset.provideExample) { _, _ in preset.lastModifiedDate = Date() }
        .onChange(of: preset.exampleRawText) { _, _ in preset.lastModifiedDate = Date() }
        .onChange(of: preset.exampleTranslatedText) { _, _ in preset.lastModifiedDate = Date() }
    }
}

#Preview {
    let mocks = PreviewMocks.shared
    return PromptPresetsView(projectManager: mocks.projectManager)
}
