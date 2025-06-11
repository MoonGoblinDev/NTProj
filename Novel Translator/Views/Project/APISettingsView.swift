import SwiftUI
import SwiftData

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var project: TranslationProject
    
    // State for the form
    @State private var apiKey: String = ""
    @State private var selectedProvider: APIConfiguration.APIProvider
    @State private var selectedModel: String
    
    // State for dynamic model loading
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelLoadingError: String?
    
    // To only show Gemini for now
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
        // Load existing key from keychain when view appears
        if let config = project.apiConfig {
            self.apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier) ?? ""
        }
        // Trigger model loading
        Task { await loadModels() }
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
            
            // If current model is not in the new list, or no model is selected, pick the first one
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
