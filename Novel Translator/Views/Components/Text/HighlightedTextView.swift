import SwiftUI

struct HighlightedTextView: View {
    // This view takes a pre-formatted Markdown string.
    let markdownContent: String

    // A computed property that safely parses the Markdown into an AttributedString.
    private var attributedString: AttributedString {
        do {
            // Explicitly create an AttributedString from the Markdown.
            // This forces SwiftUI to parse the link syntax.
            return try AttributedString(markdown: markdownContent)
        } catch {
            // If parsing fails, log the error and return the raw
            // text as a fallback to prevent a crash.
            print("Error parsing Markdown for HighlightedTextView: \(error)")
            return AttributedString(markdownContent)
        }
    }
    
    var body: some View {
        ScrollView {
            // Use the computed AttributedString here.
            Text(attributedString)
                .tint(.gold) // Make all links gold
                .font(.system(.body, design: .serif))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled) // Keep text selectable
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
