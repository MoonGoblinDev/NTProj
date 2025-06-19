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
            if viewModel.isRealCount {
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
        .help(viewModel.errorMessage ?? "An exact token count.")
        .foregroundColor(viewModel.errorMessage != nil ? .red : .secondary)
    }
    
    @ViewBuilder
    private var estimatedCountView: some View {
        HStack(spacing: 4) {
            if isHovering && canRetryForAPI {
                Button(action: viewModel.retry) {
                    Label("Get real token count", systemImage: "arrow.clockwise.circle")
                }
                .buttonStyle(.plain)
                .help("Get real token count from \(projectManager.settings.selectedProvider?.displayName ?? "provider")")
            }
            else{
                if viewModel.isLoading {
                    Text("Calculating tokens")
                }
                else{
                    Text("~ \(viewModel.tokenCount) tokens")
                }
                
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovering = hovering
            }
        }
        .help(helpText)
        .foregroundColor(viewModel.errorMessage != nil ? .red : .secondary)
    }
    
    private var canRetryForAPI: Bool {
        guard let provider = projectManager.settings.selectedProvider else { return false }
        return provider == .google || provider == .anthropic
    }
    
    private var helpText: String {
        if let error = viewModel.errorMessage {
            return error
        }
        
        guard let provider = projectManager.settings.selectedProvider else {
            return "An estimated token count."
        }
        
        switch provider {
        case .deepseek:
            return "An estimated token count (via Tiktoken)."
        case .google, .anthropic:
            return "An estimated token count. A more accurate count will be fetched from the API."
        default:
            return "An estimated token count."
        }
    }
}

#Preview {
    let mocks = PreviewMocks.shared
    return VStack(spacing: 20) {
        TokenCounterView(
            text: "This is some sample text for the token counter.",
            projectManager: mocks.projectManager,
            autoCount: true
        )
        TokenCounterView(
            text: "これはトークンカウンターのサンプルテキストです。",
            projectManager: mocks.projectManager,
            autoCount: false
        )
    }
    .padding()
    .frame(width: 300)
}
