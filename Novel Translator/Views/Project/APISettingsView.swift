// FILE: Novel Translator/Views/Project/APISettingsView.swift
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
                .navigationTitle("Providers")
            } detail: {
                ProviderSettingsRouter(
                    provider: selectedProvider,
                    projectManager: projectManager
                )
            }
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
        .frame(minWidth: 700, idealWidth: 850, minHeight: 500, idealHeight: 600)
        .onAppear {
            selectedProvider = projectManager.settings.selectedProvider ?? .google
        }
    }
    
    private func saveAndDismiss() {
        if let currentConfig = projectManager.settings.apiConfigurations.first(where: { $0.provider == projectManager.settings.selectedProvider }),
           !currentConfig.enabledModels.contains(projectManager.settings.selectedModel) {
            projectManager.settings.selectedModel = currentConfig.enabledModels.first ?? ""
        }
        
        projectManager.saveSettings()
        dismiss()
    }
}

// MARK: - Router View
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
            case .ollama:
                OllamaSettingsView(config: configBinding)
            case .openrouter:
                OpenRouterSettingsView(config: configBinding)
            case .custom:
                CustomOpenAISettingsView(config: configBinding)
            }
        } else {
            ContentUnavailableView("Configuration Not Found", systemImage: "xmark.circle")
        }
    }
}


// MARK: - Base View for Shared Logic (Refactored for Search and Sections)
fileprivate struct ProviderSettingsBaseView<Content: View>: View {
    let title: String
    @Binding var config: APIConfiguration
    let fetcher: (_ apiKey: String?, _ baseURL: String?) async throws -> [String]
    let showAPIKeyField: Bool
    let showBaseURLField: Bool
    
    // State for fetching and filtering models
    @State private var apiKey: String = ""
    @State private var baseURLInput: String = ""
    @State private var allFetchedModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelLoadingError: String?
    @State private var modelSearchQuery: String = ""

    @ViewBuilder let additionalContent: Content

    init(title: String, config: Binding<APIConfiguration>, fetcher: @escaping (_ apiKey: String?, _ baseURL: String?) async throws -> [String], showAPIKeyField: Bool, showBaseURLField: Bool, @ViewBuilder additionalContent: () -> Content = { EmptyView() }) {
        self.title = title
        self._config = config
        self.fetcher = fetcher
        self.showAPIKeyField = showAPIKeyField
        self.showBaseURLField = showBaseURLField
        self.additionalContent = additionalContent()
    }
    
    // MARK: Computed Properties for Filtered Lists
    
    private var filteredEnabledModels: [String] {
        let enabled = config.enabledModels
        if modelSearchQuery.isEmpty {
            return enabled.sorted()
        }
        return enabled.filter { $0.localizedCaseInsensitiveContains(modelSearchQuery) }.sorted()
    }
    
    private var filteredAvailableModels: [String] {
        let enabledSet = Set(config.enabledModels)
        let available = allFetchedModels.filter { !enabledSet.contains($0) }
        
        if modelSearchQuery.isEmpty {
            return available.sorted()
        }
        return available.filter { $0.localizedCaseInsensitiveContains(modelSearchQuery) }.sorted()
    }
    
    // MARK: Body
    var body: some View {
        Form {
            // API Key and Base URL sections
            if showAPIKeyField {
                Section(header: Text("API Key")) {
                    SecureField("Stored in Keychain", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in KeychainHelper.save(key: config.apiKeyIdentifier, stringValue: newValue) }
                }
            }
            if showBaseURLField {
                Section(header: Text(config.provider == .ollama ? "Ollama Server URL" : "Endpoint Base URL")) {
                    TextField("e.g., http://localhost:11434", text: $baseURLInput)
                        .onChange(of: baseURLInput) { _, newValue in config.baseURL = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
            }
            
            // Fetch button
            Button("Fetch Available Models") { Task { await loadModels() } }
                .disabled(isFetchDisabled())

            // Provider-specific additional content
            additionalContent
            
            // Model management section
            Section("Models for Translation") {
                TextField("Search Models...", text: $modelSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 4)

                if isLoadingModels {
                    HStack { ProgressView(); Text("Loading models...") }
                } else if let error = modelLoadingError {
                    Text(error).foregroundColor(.red)
                } else if allFetchedModels.isEmpty && modelSearchQuery.isEmpty {
                    Text("No models available. Ensure configuration is correct and press 'Fetch' again.").foregroundStyle(.secondary)
                } else {
                    modelLists
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
        .onAppear(perform: loadInitialData)
    }
    
    // MARK: Model List Subview
    @ViewBuilder
    private var modelLists: some View {
        // Enabled Models Section
        if !filteredEnabledModels.isEmpty {
            Section {
                ForEach(filteredEnabledModels, id: \.self) { modelName in
                    Toggle(modelName, isOn: bindingFor(model: modelName))
                }
            } header: { Text("Enabled").padding(.top) }
        }
        
        // Available Models Section
        if !filteredAvailableModels.isEmpty {
            Section {
                ForEach(filteredAvailableModels, id: \.self) { modelName in
                    Toggle(modelName, isOn: bindingFor(model: modelName))
                }
            } header: { Text("Available").padding(.top) }
        }
        
        // "No results" message for search
        if modelSearchQuery.isEmpty == false && filteredEnabledModels.isEmpty && filteredAvailableModels.isEmpty {
            ContentUnavailableView.search(text: modelSearchQuery)
        }
    }

    // MARK: Helper Methods
    private func loadInitialData() {
        self.apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) ?? ""
        self.baseURLInput = config.baseURL ?? (config.provider == .ollama ? "http://localhost:11434" : "")
        
        if !isFetchDisabled() { Task { await loadModels() } }
    }
    
    private func loadModels() async {
        isLoadingModels = true; modelLoadingError = nil
        do {
            self.allFetchedModels = try await fetcher(apiKey, config.baseURL)
        } catch {
            self.allFetchedModels = []; self.modelLoadingError = error.localizedDescription
        }
        isLoadingModels = false
    }

    private func isFetchDisabled() -> Bool {
        let keyMissing = showAPIKeyField && apiKey.isEmpty
        let urlMissing = showBaseURLField && (config.baseURL?.isEmpty ?? true)
        return keyMissing || urlMissing
    }

    private func bindingFor(model modelName: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.config.enabledModels.contains(modelName) },
            set: { isEnabled in
                if isEnabled {
                    if !config.enabledModels.contains(modelName) {
                        config.enabledModels.append(modelName)
                    }
                } else {
                    config.enabledModels.removeAll { $0 == modelName }
                }
            }
        )
    }
}

// MARK: - Provider-Specific Views (Unchanged)

fileprivate struct GeminiSettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "Google (Gemini) Settings", config: $config, fetcher: GoogleService.fetchAvailableModels, showAPIKeyField: true, showBaseURLField: false)
    }
}

fileprivate struct OpenAISettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "OpenAI Settings", config: $config, fetcher: OpenAIService.fetchAvailableModels, showAPIKeyField: true, showBaseURLField: false)
    }
}

fileprivate struct AnthropicSettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "Anthropic (Claude) Settings", config: $config, fetcher: AnthropicService.fetchAvailableModels, showAPIKeyField: true, showBaseURLField: false)
    }
}

fileprivate struct DeepseekSettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "Deepseek Settings", config: $config, fetcher: DeepseekService.fetchAvailableModels, showAPIKeyField: true, showBaseURLField: false)
    }
}

fileprivate struct OllamaSettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "Ollama (Local) Settings", config: $config, fetcher: OllamaService.fetchAvailableModels, showAPIKeyField: false, showBaseURLField: true)
    }
}

fileprivate struct OpenRouterSettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "OpenRouter Settings", config: $config, fetcher: OpenRouterService.fetchAvailableModels, showAPIKeyField: true, showBaseURLField: false) {
            Section("Optional Headers") {
                TextField("Site URL (HTTP-Referer)", text: Binding(get: { config.openRouterSiteURL ?? "" }, set: { config.openRouterSiteURL = $0 }))
                TextField("App Name (X-Title)", text: Binding(get: { config.openRouterAppName ?? "" }, set: { config.openRouterAppName = $0 }))
            }
        }
    }
}

fileprivate struct CustomOpenAISettingsView: View {
    @Binding var config: APIConfiguration
    var body: some View {
        ProviderSettingsBaseView(title: "Custom OpenAI-like Settings", config: $config, fetcher: CustomOpenAIService.fetchAvailableModels, showAPIKeyField: true, showBaseURLField: true) {
            Section("Notes") {
                Text("Use this for any OpenAI-compatible endpoint, like a local LLM server (e.g., LM Studio, Jan) or another proxy service. The API key may be optional depending on your setup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let mocks = PreviewMocks.shared
    // Let's ensure the preview has some models to show off the new UI
    if let idx = mocks.projectManager.settings.apiConfigurations.firstIndex(where: { $0.provider == .openai }) {
        mocks.projectManager.settings.apiConfigurations[idx].enabledModels = ["gpt-4o", "gpt-4o-mini"]
    }
    return APISettingsView(projectManager: mocks.projectManager)
}
