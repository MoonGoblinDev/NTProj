import SwiftUI
import SwiftData

struct PromptPresetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: TranslationProject

    @State private var selectedPresetID: UUID?

    private var sortedPresets: [PromptPreset] {
        project.promptPresets.sorted { $0.createdDate < $1.createdDate }
    }
    
    private var selectedPreset: PromptPreset? {
        guard let selectedPresetID else { return nil }
        return project.promptPresets.first { $0.id == selectedPresetID }
    }

    var body: some View {
        // Match the structure of APISettingsView: A root VStack.
        VStack(spacing: 0) {
            NavigationSplitView {
                // The sidebar column.
                VStack(spacing: 0) {
                    //Spacer().frame(height: 36)
                    List(selection: $selectedPresetID) {
                        ForEach(sortedPresets) { preset in
                            Text(preset.name)
                                .tag(preset.id as UUID?)
                        }
                        .onDelete(perform: deletePresets)
                    }
                    .listStyle(.sidebar)
                    
                    
                    Divider()
                    
                    // The action bar for the sidebar.
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
                if let preset = selectedPreset {
                    //Spacer().frame(height: 25)
                    PromptPresetDetailView(preset: preset)
                } else {
                    ContentUnavailableView("No Preset Selected", systemImage: "wand.and.stars", description: Text("Select a preset from the list or create a new one."))
                }
            }
            
            Divider()
            
            // Manual bottom bar, just like in APISettingsView.
//            HStack {
//                Spacer()
//                Button("Done") {
//                    dismiss()
//                }
//                .buttonStyle(.borderedProminent)
//                .keyboardShortcut(.defaultAction)
//            }
//            .padding()
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 500)
        .onAppear {
            if selectedPresetID == nil {
                selectedPresetID = sortedPresets.first?.id
            }
        }
    }
    
    private func addPreset() {
        let newPreset = PromptPreset(name: "New Preset", prompt: PromptPreset.defaultPrompt, project: project)
        project.promptPresets.append(newPreset)
        
        // Select the new preset automatically
        selectedPresetID = newPreset.id
    }
    
    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            let presetToDelete = sortedPresets[index]
            // If the deleted preset was the one globally selected for the project, clear it.
            if project.selectedPromptPresetID == presetToDelete.id {
                project.selectedPromptPresetID = nil
            }
            modelContext.delete(presetToDelete)
        }
        try? modelContext.save()
    }
}

fileprivate struct PromptPresetDetailView: View {
    @Bindable var preset: PromptPreset
    
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
    }
}
