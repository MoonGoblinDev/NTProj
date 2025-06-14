import SwiftUI

struct ProjectStatsView: View {
    let project: TranslationProject
    
    var body: some View {
        let currentStats = project.stats
        
        VStack {
            Form {
                Section("Progress") {
                    LabeledContent("Completed Chapters", value: "\(currentStats.completedChapters) / \(currentStats.totalChapters)")
                    LabeledContent("Translated Words", value: "\(currentStats.translatedWords) / \(currentStats.totalWords)")
                    ProgressView(value: Double(currentStats.completedChapters), total: Double(max(1, currentStats.totalChapters)))
                }
                
                Section("Cost & Usage") {
                    LabeledContent("Total Tokens Used", value: currentStats.totalTokensUsed.formatted())
                    LabeledContent("Estimated Cost", value: currentStats.estimatedCost, format: .currency(code: "USD"))
                }
                
                Section("Performance") {
                    LabeledContent("Average Translation Time / Chapter", value: "\(String(format: "%.2f", currentStats.averageTranslationTime))s")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding()
        }
        .navigationTitle("")
    }
}
