import SwiftUI

struct HighlightedTextView: View {
    @EnvironmentObject private var appContext: AppContext
    
    let lines: [[TextComponent]]

    var body: some View {
        ScrollView {
            // A simple VStack is sufficient.
            VStack(alignment: .leading, spacing: 0) {
                // We iterate over the lines with an index to get a stable ID.
                ForEach(lines.indices, id: \.self) { lineIndex in
                    // Pass each line to a dedicated LineView.
                    LineView(
                        components: lines[lineIndex],
                        onTapEntry: { entry in
                            appContext.glossaryEntryToEditID = entry.id
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

/// A new helper view responsible for rendering a single line of text.
/// This is where the logic to separate tappable and selectable views lives.
private struct LineView: View {
    let components: [TextComponent]
    let onTapEntry: (GlossaryEntry) -> Void
    
    /// A private struct to group consecutive plain text components together.
    /// This is key for enabling smooth text selection across multiple plain words.
    private struct ComponentGroup: Identifiable, Hashable {
        let id = UUID()
        let isGlossary: Bool
        let text: String
        let entry: GlossaryEntry?
    }
    
    /// Groups consecutive plain text components into a single block.
    private var groupedComponents: [ComponentGroup] {
        var groups: [ComponentGroup] = []
        var currentPlainText = ""

        for component in components {
            switch component {
            case .plain(let text):
                // Keep accumulating plain text.
                currentPlainText += text
            case .glossary(let text, let entry):
                // 1. If there's pending plain text, add it as a group first.
                if !currentPlainText.isEmpty {
                    groups.append(ComponentGroup(isGlossary: false, text: currentPlainText, entry: nil))
                    currentPlainText = ""
                }
                // 2. Add the glossary term as its own group.
                groups.append(ComponentGroup(isGlossary: true, text: text, entry: entry))
            }
        }
        
        // Add any remaining plain text at the end.
        if !currentPlainText.isEmpty {
            groups.append(ComponentGroup(isGlossary: false, text: currentPlainText, entry: nil))
        }
        
        return groups
    }
    
    var body: some View {
        // If the line is effectively empty, render a space to keep the line height.
        if components.isEmpty || (components.count == 1 && (components.first == .plain(""))) {
            Text(" ")
                .font(.system(.body, design: .serif))
                .frame(height: 20) // Give it a consistent height
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(groupedComponents) { group in
                    if group.isGlossary {
                        // Glossary terms are tappable but NOT selectable.
                        Text(group.text)
                            .bold()
                            .foregroundColor(.gold)
                            .underline()
                            .onTapGesture {
                                if let entry = group.entry {
                                    onTapEntry(entry)
                                }
                            }
                    } else {
                        // Plain text blocks are selectable.
                        Text(group.text)
                            .textSelection(.enabled)
                    }
                }
                // Push content to the left.
                Spacer()
            }
            .font(.system(.body, design: .serif))
        }
    }
}
