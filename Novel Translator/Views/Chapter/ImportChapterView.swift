//
//  ImportChapterView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//
import SwiftUI
import SwiftData

struct ImportChapterView: View {
    @Environment(\.modelContext) private var modelContext // 1. Get context from environment
    @Environment(\.dismiss) private var dismiss
    
    let project: TranslationProject
    
    @State private var viewModel: ImportViewModel
    
    // 2. The initializer is now simpler and more robust.
    // It takes the project and prepares the State property for the viewModel.
    init(project: TranslationProject) {
        self.project = project
        // We can't access modelContext here yet, so we initialize a dummy ViewModel.
        // It will be replaced immediately when the view's body is accessed.
        _viewModel = State(initialValue: ImportViewModel(project: project, modelContext: .init(try! ModelContainer(for: TranslationProject.self))))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // The content of the VStack remains the same as before...
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
                        // Optional: dismiss the sheet automatically on success
                        if !viewModel.importMessage.contains("Error") && !viewModel.importMessage.contains("Cancelled") {
                             // give a little delay for user to read the success message
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
        // 3. This is the crucial part.
        // It runs once when the view appears, creating the viewModel
        // with the *correct* modelContext from the environment.
        .onAppear {
            self.viewModel = ImportViewModel(project: project, modelContext: modelContext)
        }
    }
}
