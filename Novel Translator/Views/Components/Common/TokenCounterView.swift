import SwiftUI

struct TokenCounterView: View {
    let text: String
    @ObservedObject var projectManager: ProjectManager
    let autoCount: Bool

    @State private var viewModel: TokenCounterViewModel

    @State private var isHovering = false

    init(text: String, projectManager: ProjectManager, autoCount: Bool) {
        self.text = text
        self.projectManager = projectManager
        self.autoCount = autoCount
        _viewModel = State(initialValue: TokenCounterViewModel(settings: projectManager.settings, autoCount: autoCount))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if viewModel.isRealCount {
                realCountView
            } else {
                estimatedCountView
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .onAppear {
            viewModel.updateText(text)
        }
        .onChange(of: text) { _, newText in
            viewModel.updateText(newText)
        }
        .onChange(of: projectManager.settings.selectedModel) {
            // Re-fetch if the model changes
            viewModel.settingsDidChange(newSettings: projectManager.settings)
        }
    }
    
    @ViewBuilder
    private var realCountView: some View {
        HStack(spacing: 4) {
            if let provider = projectManager.settings.selectedProvider {
                Image(systemName: provider.logoName)
                    .foregroundColor(provider.logoColor)
            }
            Text("\(viewModel.tokenCount) tokens")
        }
    }
    
    @ViewBuilder
    private var estimatedCountView: some View {
        HStack(spacing: 4) {
            if isHovering {
                Button(action: viewModel.retry) {
                    Label("Get real token count", systemImage: "arrow.clockwise.circle")
                }
                .buttonStyle(.plain)
                .help("Get real token count from \(projectManager.settings.selectedProvider?.displayName ?? "provider")")
            }
            else{
                Text("~ \(viewModel.tokenCount) tokens")
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut) {
                self.isHovering = hovering
            }
        }
        .help(viewModel.errorMessage ?? "An estimated token count based on word count.")
        .foregroundColor(viewModel.errorMessage != nil ? .red : .secondary)
    }
}
