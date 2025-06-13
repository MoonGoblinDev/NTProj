//
//  ImportChapterView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//
import SwiftUI
import SwiftData

struct ImportChapterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: TranslationProject
    
    @State private var viewModel: ImportViewModel
    
    init(project: TranslationProject) {
        self.project = project
        _viewModel = State(initialValue: ImportViewModel(project: project, modelContext: .init(try! ModelContainer(for: TranslationProject.self))))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isImporting {
                VStack {
                    ProgressView()
                    Text(viewModel.importMessage)
                        .font(.headline)
                        .padding(.top)
                }
                .progressViewStyle(.circular)
                .padding()
                
            } else {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Import Chapters")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select one or more `.txt` files, or a folder containing them. Each file can be treated as a single chapter, or split into multiple chapters based on a separator defined in your project settings.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if !viewModel.importMessage.isEmpty && viewModel.importMessage != "Selecting files..." {
                    Text(viewModel.importMessage)
                        .font(.footnote)
                        .foregroundColor(viewModel.importMessage.contains("Error") ? .red : .green)
                        .padding()
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Select Files...") {
                    Task {
                        await viewModel.startImport()
                        if !viewModel.importMessage.contains("Error") && !viewModel.importMessage.contains("Cancelled") {
                             try? await Task.sleep(for: .seconds(1.5))
                             dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting)
            }
        }
        .padding(30)
        .frame(minWidth: 450, idealWidth: 500, minHeight: 350)
        .onAppear {
            self.viewModel = ImportViewModel(project: project, modelContext: modelContext)
        }
    }
}

#Preview {
    // Use a Query to get the project from the container
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        
        var body: some View {
            if let project = projects.first {
                ImportChapterView(project: project)
            } else {
                Text("No project found for preview.")
            }
        }
    }
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    container.mainContext.insert(TranslationProject(name: "Sample Project", sourceLanguage: "JP", targetLanguage: "EN"))
    
    return Previewer()
        .modelContainer(container)
}
