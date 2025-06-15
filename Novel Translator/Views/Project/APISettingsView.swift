import SwiftUI

// MARK: - Main APISettingsView (Sheet Entry Point)
struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var projectManager: ProjectManager
    
    @State private var selectedProvider: APIConfiguration.APIProvider = .google
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(APIConfiguration.APIProvider.allCases, selection: $selectedProvider) { provider in
                    Text(provider.displayName).tag(provider)
                }
                .navigationTitle("")
            } detail: {
                // The router view decides which specific settings view to display.
                ProviderSettingsRouter(
                    provider: selectedProvider,
                    projectManager: projectManager
                )
            }
            .navigationTitle("")
            .navigationSplitViewStyle(.balanced)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    saveAndDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 750, minHeight: 450, idealHeight: 550)
        .onAppear {
            selectedProvider = projectManager.settings.selectedProvider ?? .google
        }
    }
    
    private func saveAndDismiss() {
        // Ensure the selected model is valid
        if let currentConfig = projectManager.settings.apiConfigurations.first(where: { $0.provider == projectManager.settings.selectedProvider }),
           !currentConfig.enabledModels.contains(projectManager.settings.selectedModel) {
            // If the currently selected model was just disabled, pick another enabled one.
            projectManager.settings.selectedModel = currentConfig.enabledModels.first ?? ""
        }
        
        projectManager.saveSettings()
        dismiss()
    }
}

// MARK: - Router View
/// This view is the key to fixing the update bug. It switches between the specific
/// provider setting views, forcing SwiftUI to create a new view instance on selection change.
fileprivate struct ProviderSettingsRouter: View {
    let provider: APIConfiguration.APIProvider
    @ObservedObject var projectManager: ProjectManager

    var body: some View {
        if let configIndex = projectManager.settings.apiConfigurations.firstIndex(where: { $0.provider == provider }) {
            let configBinding = $projectManager.settings.apiConfigurations[configIndex]
            
            switch provider {
            case .google:
                GeminiSettingsView(config: configBinding)
            case .openai:
                OpenAISettingsView(config: configBinding)
            case .anthropic:
                AnthropicSettingsView(config: configBinding)
            case .deepseek:
                DeepseekSettingsView(config: configBinding)
            }
        } else {
            ContentUnavailableView("Configuration Not Found", systemImage: "xmark.circle")
        }
    }
}


// MARK: - Base View for Shared Logic
/// A base view that contains the common UI and logic for fetching and displaying models.
/// This avoids code duplication in the specific provider views.
fileprivate struct ProviderSettingsBaseView<Content: View>: View {
    let title: String
    @Binding var config: APIConfiguration
    let fetcher: (_ apiKey: String) async throws -> [String]
    
    @State private var apiKey: String = ""
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelLoadingError: String?
    
    // Optional additional content for provider-specific settings
    @ViewBuilder let additionalContent: Content

    init(title: String, config: Binding<APIConfiguration>, fetcher: @escaping (_ apiKey: String) async throws -> [String], @ViewBuilder additionalContent: () -> Content = { EmptyView() }) {
        self.title = title
        self._config = config
        self.fetcher = fetcher
        self.additionalContent = additionalContent()
    }

    var body: some View {
        Form {
            Section("API Key") {
                SecureField("Stored in Keychain", text: $apiKey)
                    .onChange(of: apiKey) { _, newValue in
                        KeychainHelper.save(key: config.apiKeyIdentifier, stringValue: newValue)
                    }
                
                Button("Fetch Available Models") {
                    Task { await loadModels() }
                }
                .disabled(apiKey.isEmpty)
            }
            
            // Allow for provider-specific form sections
            additionalContent
            
            Section("Enabled Models for Translation") {
                if isLoadingModels {
                    HStack { ProgressView(); Text("Loading models...") }
                } else if let error = modelLoadingError {
                    Text(error).foregroundColor(.red)
                } else if availableModels.isEmpty {
                    Text("No models available. Fetch them using your API key.").foregroundStyle(.secondary)
                } else {
                    List(availableModels, id: \.self) { modelName in
                        Toggle(modelName, isOn: bindingFor(model: modelName))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
        .onAppear(perform: loadInitialData)
    }

    private func loadInitialData() {
        self.apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) ?? ""
        if !apiKey.isEmpty { Task { await loadModels() } }
    }
    
    private func loadModels() async {
        guard !apiKey.isEmpty else {
            self.availableModels = []; self.modelLoadingError = "API Key is required."
            return
        }
        isLoadingModels = true; modelLoadingError = nil
        do {
            self.availableModels = try await fetcher(apiKey)
        } catch {
            self.availableModels = []; self.modelLoadingError = error.localizedDescription
        }
        isLoadingModels = false
    }

    private func bindingFor(model modelName: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.config.enabledModels.contains(modelName) },
            set: { isEnabled in
                if isEnabled {
                    if !config.enabledModels.contains(modelName) {
                        config.enabledModels.append(modelName); config.enabledModels.sort()
                    }
                } else {
                    config.enabledModels.removeAll { $0 == modelName }
                }
            }
        )
    }
}

// MARK: - Provider-Specific Views

fileprivate struct GeminiSettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(
            title: "Google (Gemini) Settings",
            config: $config,
            fetcher: GoogleService.fetchAvailableModels
        )
    }
}

fileprivate struct OpenAISettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(
            title: "OpenAI Settings",
            config: $config,
            fetcher: OpenAIService.fetchAvailableModels
        )
    }
}

fileprivate struct AnthropicSettingsView: View {
    @Binding var config: APIConfiguration

    var body: some View {
        ProviderSettingsBaseView(
            title: "Anthropic (Claude) Settings",
            config: $config,
            fetcher: AnthropicService.fetchAvailableModels
        )
    }
}

fileprivate struct DeepseekSettingsView: View {
    @Binding var config: APIConfiguration

    var body: some View {
        ProviderSettingsBaseView(
            title: "Deepseek Settings",
            config: $config,
            fetcher: DeepseekService.fetchAvailableModels
        )
    }
}
