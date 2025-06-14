import SwiftUI

struct ImportChapterView: View {
    @Environment(\.dismiss) private var dismiss
    
    let project: TranslationProject
    
    @State private var viewModel: ImportViewModel
    
    init(project: TranslationProject) {
        self.project = project
        _viewModel = State(initialValue: ImportViewModel(project: project))
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
    }
}
