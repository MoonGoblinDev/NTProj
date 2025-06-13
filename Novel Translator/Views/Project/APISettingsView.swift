import SwiftUI
import SwiftData

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var project: TranslationProject
    
    @State private var apiKey: String = ""
    @State private var selectedProvider: APIConfiguration.APIProvider
    @State private var selectedModel: String
    
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelLoadingError: String?
    
    private let availableProviders: [APIConfiguration.APIProvider] = [.google]
    
    init(project: TranslationProject) {
        self.project = project
        if let config = project.apiConfig {
            _selectedProvider = State(initialValue: config.provider)
            _selectedModel = State(initialValue: config.model)
        } else {
            _selectedProvider = State(initialValue: .google)
            _selectedModel = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack {
            Form {
                Section("API Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(availableProviders, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    SecureField("API Key (Stored in Keychain)", text: $apiKey)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Picker("Model", selection: $selectedModel) {
                                ForEach(availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .disabled(isLoadingModels || availableModels.isEmpty)
                            
                            if isLoadingModels {
                                ProgressView().scaleEffect(0.5)
                            }
                        }
                        
                        if let error = modelLoadingError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    saveConfiguration()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedModel.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 300)
        .navigationTitle("API Settings")
        .onAppear(perform: loadInitialData)
        .onChange(of: apiKey) { _, _ in
            Task { await loadModels() }
        }
    }
    
    private func loadInitialData() {
        if let config = project.apiConfig {
            self.apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) ?? ""
        }
        Task {
            // For preview, we won't call the network. Just populate with dummy data.
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                self.availableModels = ["gemini-1.5-pro-preview", "gemini-1.5-flash-preview"]
                self.selectedModel = "gemini-1.5-flash-preview"
                return
            }
            #endif
            await loadModels()
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
            let models = try await GoogleService.fetchAvailableModels(apiKey: self.apiKey)
            self.availableModels = models
            if !models.contains(selectedModel) || selectedModel.isEmpty {
                selectedModel = models.first ?? ""
            }
            
        } catch {
            self.availableModels = []
            self.modelLoadingError = error.localizedDescription
        }
        
        isLoadingModels = false
    }
    
    private func saveConfiguration() {
        guard let config = project.apiConfig else { return }
        
        let status = KeychainHelper.save(key: config.apiKeyIdentifier, stringValue: apiKey)
        if status != noErr {
            print("Error: Failed to save API key to Keychain. Status: \(status)")
        }
        
        config.provider = selectedProvider
        config.model = selectedModel
        project.lastModifiedDate = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save API configuration: \(error)")
        }
    }
}

#Preview {
    struct Previewer: View {
        @Query private var projects: [TranslationProject]
        var body: some View {
            NavigationStack {
                 APISettingsView(project: projects.first!)
            }
        }
    }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TranslationProject.self, configurations: config)
    
    let project = TranslationProject(name: "My Awesome Novel", sourceLanguage: "Japanese", targetLanguage: "English")
    let apiConfig = APIConfiguration(provider: .google, model: "gemini-1.5-flash-preview")
    project.apiConfig = apiConfig
    container.mainContext.insert(project)

    return Previewer()
        .modelContainer(container)
}
