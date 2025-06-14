import SwiftUI
import SwiftData

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var project: TranslationProject
    
    @State private var selectedProvider: APIConfiguration.APIProvider = .google
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(APIConfiguration.APIProvider.allCases, selection: $selectedProvider) { provider in
                    Text(provider.displayName).tag(provider)
                }
                .navigationTitle("")
            } detail: {
                if let config = project.apiConfigurations.first(where: { $0.provider == selectedProvider }) {
                    ProviderSettingsDetailView(config: config, project: project)
                } else {
                    ContentUnavailableView("Configuration Not Found", systemImage: "xmark.circle")
                }
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
    }
    
    private func saveAndDismiss() {
        // Ensure the selected model is valid
        if let currentConfig = project.apiConfigurations.first(where: { $0.provider == project.selectedProvider }),
           !currentConfig.enabledModels.contains(project.selectedModel) {
            // If the currently selected model was just disabled, pick another enabled one.
            project.selectedModel = currentConfig.enabledModels.first ?? ""
        }
        
        // Save the context
        do {
            try modelContext.save()
        } catch {
            print("Failed to save API configurations: \(error)")
        }
        dismiss()
    }
}

// Detail view for a single provider's settings
fileprivate struct ProviderSettingsDetailView: View {
    @Bindable var config: APIConfiguration
    @Bindable var project: TranslationProject
    
    @State private var apiKey: String = ""
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelLoadingError: String?
    
    var body: some View {
        Form {
            Section("API Key") {
                SecureField("Stored in Keychain", text: $apiKey)
                    .onChange(of: apiKey) { _, newValue in
                        // Save key immediately, but only trigger model loading after a delay
                        KeychainHelper.save(key: config.apiKeyIdentifier, stringValue: newValue)
                    }
                
                Button("Fetch Available Models") {
                    Task { await loadModels() }
                }
                .disabled(apiKey.isEmpty)
            }
            
            Section("Enabled Models for Translation") {
                if isLoadingModels {
                    HStack {
                        ProgressView()
                        Text("Loading models...")
                    }
                } else if let error = modelLoadingError {
                    Text(error)
                        .foregroundColor(.red)
                } else if availableModels.isEmpty {
                    Text("No models available. Fetch them using your API key.")
                        .foregroundStyle(.secondary)
                } else {
                    List(availableModels, id: \.self) { modelName in
                        Toggle(modelName, isOn: bindingFor(model: modelName))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("")
        .onAppear(perform: loadInitialData)
    }
    
    private func loadInitialData() {
        self.apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) ?? ""
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            self.availableModels = config.provider.defaultModels
            return
        }
        #endif
        
        // Load models if key exists
        if !apiKey.isEmpty {
            Task { await loadModels() }
        }
    }
    
    private func loadModels() async {
        guard !apiKey.isEmpty else {
            self.availableModels = []
            self.modelLoadingError = "API Key is required to fetch models."
            return
        }
        
        isLoadingModels = true
        modelLoadingError = nil
        
        do {
            switch config.provider {
            case .google:
                self.availableModels = try await GoogleService.fetchAvailableModels(apiKey: self.apiKey)
            case .openai, .anthropic:
                // For other providers, use the hardcoded default list for now
                self.availableModels = config.provider.defaultModels
            }
        } catch {
            self.availableModels = []
            self.modelLoadingError = error.localizedDescription
        }
        
        isLoadingModels = false
    }
    
    private func bindingFor(model modelName: String) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                self.config.enabledModels.contains(modelName)
            },
            set: { isEnabled in
                if isEnabled {
                    if !config.enabledModels.contains(modelName) {
                        config.enabledModels.append(modelName)
                        config.enabledModels.sort()
                    }
                } else {
                    config.enabledModels.removeAll { $0 == modelName }
                }
                project.lastModifiedDate = Date()
            }
        )
    }
}

#Preview {
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        var body: some View {
            if let project = projects.first {
                APISettingsView(project: project)
            } else {
                Text("Loading preview...")
            }
        }
    }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    let modelContext = container.mainContext
    
    let project = TranslationProject(name: "My Awesome Novel", sourceLanguage: "Japanese", targetLanguage: "English")
    
    for provider in APIConfiguration.APIProvider.allCases {
        let apiConfig = APIConfiguration(provider: provider)
        apiConfig.apiKeyIdentifier = "com.noveltranslator.\(project.id.uuidString).\(provider.rawValue)"
        if provider == .google {
            apiConfig.enabledModels = ["gemini-1.5-flash-latest"]
        }
        project.apiConfigurations.append(apiConfig)
        modelContext.insert(apiConfig)
    }
    project.selectedModel = "gemini-1.5-flash-latest"
    modelContext.insert(project)

    return Previewer()
        .modelContainer(container)
}
