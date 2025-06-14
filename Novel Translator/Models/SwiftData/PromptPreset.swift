import Foundation

struct PromptPreset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var prompt: String
    var createdDate: Date = Date()
    var lastModifiedDate: Date = Date()

    init(name: String, prompt: String) {
        self.name = name
        self.prompt = prompt
    }
    
    static var defaultPrompt: String {
        """
        You are an expert novel translator. Your task is to translate the following text from {{SOURCE_LANGUAGE}} to {{TARGET_LANGUAGE}}.
        Preserve the original tone, style, and formatting, including line breaks.
        
        {{GLOSSARY}}
        Now, translate the following text:
        --- TEXT TO TRANSLATE START ---
        {{TEXT}}
        --- TEXT TO TRANSLATE END ---
        """
    }
}
