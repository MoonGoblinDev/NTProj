import SwiftUI

@MainActor
@Observable
class TokenCounterViewModel {
    // MARK: - Public State
    var tokenCount: Int = 0
    var isRealCount: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Private Properties
    private var project: TranslationProject
    private let autoCount: Bool
    private var textToCount: String = ""
    private var debounceTask: Task<Void, Never>?
    
    init(project: TranslationProject, autoCount: Bool) {
        self.project = project
        self.autoCount = autoCount
    }

    /// Primary entry point to update the text and trigger a debounced count.
    func updateText(_ newText: String) {
        self.textToCount = newText
        
        // Always provide an immediate fallback estimate
        self.tokenCount = newText.estimateTokens()
        self.isRealCount = false
        self.isLoading = false
        self.errorMessage = nil
        
        // Cancel any previous debouncing task
        debounceTask?.cancel()
        
        // Only start the debounced task if auto-counting is enabled
        guard autoCount else { return }
        
        // Don't bother with API calls for empty text or if no API key is set for the provider
        guard !newText.isEmpty, let config = project.apiConfigurations.first(where: { $0.provider == project.selectedProvider }),
              let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
            return
        }
        
        // Start a new debounced task
        debounceTask = Task {
            do {
                // Wait for 500ms after the last keystroke
                try await Task.sleep(for: .milliseconds(500))
                
                // If the task wasn't cancelled, proceed with the API call
                await fetchRealTokenCount()
                
            } catch {
                // This catch block handles the Task.sleep cancellation
            }
        }
    }
    
    /// Manually triggers a fetch, bypassing the debounce.
    func retry() {
        debounceTask?.cancel()
        guard !textToCount.isEmpty else { return }
        Task {
            await fetchRealTokenCount()
        }
    }
    
    private func fetchRealTokenCount() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let provider = project.selectedProvider else {
                throw URLError(.userAuthenticationRequired) // Or a more specific error
            }
            guard let config = project.apiConfigurations.first(where: { $0.provider == provider }) else {
                 throw URLError(.userAuthenticationRequired)
            }
            let service = try LLMServiceFactory.create(provider: provider, config: config)
            
            let count = try await service.countTokens(text: self.textToCount, model: project.selectedModel)
            
            // Update state on success
            self.tokenCount = count
            self.isRealCount = true
            
        } catch {
            // Update state on failure
            self.errorMessage = error.localizedDescription
            self.isRealCount = false // Revert to estimated state
        }
        
        self.isLoading = false
    }
}
