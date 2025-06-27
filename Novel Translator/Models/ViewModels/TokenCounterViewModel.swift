// FILE: Novel Translator/Models/ViewModels/TokenCounterViewModel.swift
import SwiftUI
import Tiktoken

@MainActor
@Observable
class TokenCounterViewModel {
    // MARK: - Public State
    var tokenCount: Int = 0
    var isRealCount: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Private Properties
    private var settings: AppSettings
    private let autoCount: Bool
    private var textToCount: String = ""
    private var debounceTask: Task<Void, Never>?
    
    init(settings: AppSettings, autoCount: Bool) {
        self.settings = settings
        self.autoCount = autoCount
    }

    /// Primary entry point to update the text and trigger a debounced count.
    func updateText(_ newText: String) {
        self.textToCount = newText
        
        // Cancel any previous debouncing task
        debounceTask?.cancel()
        
        // Immediately start a task to get a count (either real or estimated)
        Task {
            await self.updateCount(for: newText)
        }
    }
    
    /// Manually triggers a fetch, bypassing the debounce.
    func retry() {
        debounceTask?.cancel()
        guard !textToCount.isEmpty else { return }
        
        guard let provider = settings.selectedProvider else { return }

        switch provider {
        case .openai, .deepseek, .ollama, .openrouter, .custom: // Group all local/estimated counters
            // For local counters, "retry" just recalculates.
            Task { await self.updateCount(for: textToCount) }
        case .google, .anthropic:
            // For API counters, "retry" fetches from the API now.
            Task { await fetchRealTokenCountFromAPI() }
        }
    }

    /// Call this when the model or settings change
    func settingsDidChange(newSettings: AppSettings) {
        self.settings = newSettings
        // Re-trigger the counting logic with the new settings.
        updateText(textToCount)
    }
    
    private func updateCount(for text: String) async {
        // Reset state for every new update
        self.isLoading = false
        self.errorMessage = nil

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.tokenCount = 0
            self.isRealCount = true // 0 is an exact count
            return
        }

        guard let provider = settings.selectedProvider else {
            self.tokenCount = 0
            self.isRealCount = false
            return
        }

        switch provider {
        case .openai:
            // For OpenAI, Tiktoken is the real count and it's fast.
            do {
                self.tokenCount = try await countWithTiktoken(text: text, model: settings.selectedModel)
                self.isRealCount = true
            } catch {
                self.errorMessage = error.localizedDescription
                self.tokenCount = 0
                self.isRealCount = false
            }

        case .deepseek, .ollama, .openrouter, .custom: // Group all providers estimated with TikToken
            // For these, Tiktoken is an estimate, but it's the best we can do locally.
            do {
                // Use a default gpt-4 model for encoding as it's compatible
                self.tokenCount = try await countWithTiktoken(text: text, model: "gpt-4")
                self.isRealCount = false // It's an estimate
            } catch {
                self.errorMessage = error.localizedDescription
                self.tokenCount = 0
                self.isRealCount = false
            }

        case .google, .anthropic:
            // Set an initial estimate using Tiktoken, then fetch real count from API.
            do {
                self.tokenCount = try await countWithTiktoken(text: text, model: "gpt-4") // A general estimate
                self.isRealCount = false
            } catch {
                self.tokenCount = 0
                self.isRealCount = false
            }
            
            // Only start the debounced API call if auto-counting is enabled.
            guard autoCount,
                  let config = settings.apiConfigurations.first(where: { $0.provider == provider }),
                  let apiKey = KeychainHelper.loadString(key: config.apiKeyIdentifier), !apiKey.isEmpty else {
                return
            }
            
            debounceTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                    await fetchRealTokenCountFromAPI()
                } catch { /* Task cancelled */ }
            }
        }
    }
    
    /// Helper to get count using Tiktoken.
    private func countWithTiktoken(text: String, model: String) async throws -> Int {
        let count = try await getTokenCount(for: text, model: model)
        return count
    }
    
    private func fetchRealTokenCountFromAPI() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let provider = settings.selectedProvider else {
                throw URLError(.userAuthenticationRequired)
            }
            guard let config = settings.apiConfigurations.first(where: { $0.provider == provider }) else {
                 throw URLError(.userAuthenticationRequired)
            }
            let service = try LLMServiceFactory.create(provider: provider, config: config)
            
            let count = try await service.countTokens(text: self.textToCount, model: settings.selectedModel)
            
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
