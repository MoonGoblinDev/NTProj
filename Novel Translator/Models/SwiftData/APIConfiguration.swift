import Foundation
import SwiftUI

struct APIConfiguration: Codable, Identifiable {
    var id: UUID = UUID()
    var provider: APIProvider
    var apiKeyIdentifier: String
    var maxTokens: Int
    var temperature: Double
    var enabledModels: [String] = []
    var createdDate: Date = Date()
    
    enum APIProvider: String, CaseIterable, Codable, Identifiable {
        var id: String { self.rawValue }

        case google = "google"
        case openai = "openai"
        case anthropic = "anthropic"
        
        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .google: return "Google"
            }
        }
        
        var defaultModels: [String] {
            switch self {
            case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"]
            case .anthropic: return ["claude-3-5-sonnet-20240620", "claude-3-haiku-20240307"]
            case .google: return ["gemini-1.5-flash-latest"]
            }
        }

        var logoName: String {
            switch self {
            case .google: "g.circle.fill"
            case .openai: "brain.head.profile"
            case .anthropic: "a.circle.fill"
            }
        }

        var logoColor: Color {
            switch self {
            case .google: .blue
            case .openai: .green
            case .anthropic: .orange
            }
        }
    }
    
    init(provider: APIProvider) {
        self.provider = provider
        self.apiKeyIdentifier = ""
        self.maxTokens = 8192
        self.temperature = 0.3
        self.enabledModels = []
    }
}
